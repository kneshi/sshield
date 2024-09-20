#!/bin/bash

set -euo pipefail

# Define color variables
bold_blue="\e[1;34m"
bold_green="\e[1;32m"
bold_red="\e[1;31m"
reset="\e[0m"

# Function to print error messages and exit
error_exit() {
    echo -e "${bold_red}Error: $1${reset}" >&2
    exit 1
}

# Function to check if sudo command is available and if the user has sudo privileges
check_sudo() {
    command -v sudo &>/dev/null || error_exit "sudo command not found."
    sudo -n true 2>/dev/null || error_exit "You do not have sudo privileges or a password is required (try with: sudo ./sshield.sh)."
}

# Function to check if sshd command is available and install OpenSSH server if not found
check_sshd() {
    if ! command -v sshd &>/dev/null; then
        echo -e "${bold_red}Warning: sshd command not found.${reset}"
        read -p "Do you want to install OpenSSH server? (y/n) > " -r choice
        if [[ $choice =~ ^[Yy]$ ]]; then
            if command -v apt-get &>/dev/null; then
                sudo apt-get update && sudo apt-get install -y openssh-server
            elif command -v yum &>/dev/null; then
                sudo yum install -y openssh-server
            elif command -v dnf &>/dev/null; then
                sudo dnf install -y openssh-server
            else
                error_exit "Unsupported package manager."
            fi
        else
            error_exit "sshd command is required."
        fi
    fi
}

# Function to select a params file
select_params_file() {
    local options=()
    local choice

    echo -e "Parameters available:"
    local files=(configs/*)
    [ ${#files[@]} -eq 0 ] && error_exit "No configuration files found in the configs/ directory."

    for i in "${!files[@]}"; do
        local filename=$(basename "${files[i]}")
        local comment=$(sed -n '1s/^# *//p' "${files[i]}")
        options+=("$comment")
        echo -e "[$i] ${bold_blue}$comment${reset}"
    done

    echo -e ""
    while true; do
        read -p "Select the option you want > " choice
        echo -e ""

        if [[ $choice =~ ^[0-9]+$ ]] && ((choice >= 0 && choice < ${#options[@]})); then
            break
        else
            echo -e "${bold_red}Invalid choice. Please retry with a valid option.${reset}"
        fi
    done

    params_file="${files[choice]}"
    [ ! -f "$params_file" ] && error_exit "Parameter file '$params_file' not found."

    echo "Debug: Selected params_file: $params_file"
}

# Function to read parameters from an external file
read_params() {
    [ ! -f "$params_file" ] && error_exit "Parameter file '$params_file' not found."
    
    echo "Debug: Reading params from file: $params_file"
    
    mapfile -t params < <(sed '/^#/d' "$params_file") # Ignore lines starting with #

    echo "Debug: Number of params read: ${#params[@]}"

    for line in "${params[@]}"; do
        if [[ ! $line =~ ^[^:]+:[^:]+:[^:]+$ ]]; then
            echo "Debug: Invalid line format: $line"
            error_exit "Invalid format in params file $params_file"
        fi
    done

    echo "Debug: Params read successfully"
}

# Function to create input fields for parameters
create_field() {
    local param_info=("$1")
    IFS=":" read -ra param <<<"${param_info}"
    local param_name="${param[0]}"
    local param_comment="${param[1]}"
    local param_recommendation="${param[2]}"

    echo -e "${bold_blue}${param_name}${reset}: ${param_comment}" >&2
    echo -e "Recommended value: ${bold_green}${param_recommendation}${reset}" >&2
    read -p "Enter your preferred value for ${param_name} > " -r value

    if [ -z "$value" ]; then
        value="$param_recommendation"
    elif [ "$value" != "!" ]; then
        value=$(validate_input "$param_name" "$value" "$param_recommendation")
    fi

    echo "$value"
}

# Function to generate the SSH server configuration
generate_config() {
    local config=""
    config+="Include /etc/ssh/sshd_config.d/*.conf\n\n"
    for param_info in "${params[@]}"; do
        IFS=":" read -ra param <<< "$param_info"
        local param_name="${param[0]}"
        local param_comment="${param[1]}"
        local value=$(create_field "$param_info")
        if [ "$value" != "!" ]; then
            config+="# ${param_comment}\n"
            config+="${param_name} ${value}\n\n"
        fi
        echo >&2
    done
    echo -e "$config" > sshd_config_generated.md
}

# Function to check the generated configuration for errors
check_generated_config() {
    sshd -t -f sshd_config_generated.md || error_exit "There is a problem with the generated configuration. Please check sshd_config_generated.md"
}

# Function to check if SSH service is running
check_ssh_service() {
    systemctl is-active --quiet ssh || systemctl is-active --quiet sshd
}

# Function to restart SSH based on the Linux distribution
restart_ssh() {
    if ! check_ssh_service; then
        echo -e "${bold_red}SSH service is not running. Starting it now.${reset}"
    fi

    if [ -f /etc/os-release ]; then
        source /etc/os-release
        case "$ID" in
        debian | ubuntu)
            sudo service ssh restart || error_exit "Failed to restart SSH. You may need to do it manually."
            ;;
        centos | rhel | fedora)
            sudo systemctl restart sshd || error_exit "Failed to restart SSH. You may need to do it manually."
            ;;
        alpine)
            sudo rc-service sshd restart || error_exit "Failed to restart SSH. You may need to do it manually."
            ;;
        *)
            error_exit "Unsupported Linux distribution. You may need to manually restart SSH."
            ;;
        esac
    else
        error_exit "Unable to determine the Linux distribution. You may need to manually restart SSH."
    fi

    check_ssh_service && echo -e "${bold_green}SSH service is now running.${reset}" || error_exit "Failed to start SSH service. Please check your system logs."
}

# Function to validate input
validate_input() {
    local param_name="$1"
    local value="$2"
    local recommendation="$3"

    case "$param_name" in
        Port)
            if ! [[ "$value" =~ ^[1-9][0-9]{0,4}$ ]] || [ "$value" -gt 65535 ]; then
                echo -e "${bold_red}Error: Invalid port number. Using recommended value.${reset}" >&2
                echo "$recommendation"
                return
            fi
            ;;
        Protocol)
            if [[ ! "$value" =~ ^[12]$ ]]; then
                echo -e "${bold_red}Error: Invalid Protocol version. Using recommended value.${reset}" >&2
                echo "$recommendation"
                return
            fi
            ;;
        MaxAuthTries)
            if ! [[ "$value" =~ ^[1-9][0-9]*$ ]] || [ "$value" -gt 6 ]; then
                echo -e "${bold_red}Error: MaxAuthTries must be a positive integer not greater than 6. Using recommended value.${reset}" >&2
                echo "$recommendation"
                return
            fi
            ;;
        LoginGraceTime)
            if ! [[ "$value" =~ ^[1-9][0-9]*$ ]] || [ "$value" -gt 120 ]; then
                echo -e "${bold_red}Error: LoginGraceTime must be a positive integer not greater than 120. Using recommended value.${reset}" >&2
                echo "$recommendation"
                return
            fi
            ;;
        PermitRootLogin)
            if [[ ! "$value" =~ ^(yes|no|prohibit-password|forced-commands-only)$ ]]; then
                echo -e "${bold_red}Error: Invalid value for PermitRootLogin. Using recommended value.${reset}" >&2
                echo "$recommendation"
                return
            fi
            ;;
        PasswordAuthentication | X11Forwarding)
            if [[ ! "$value" =~ ^(yes|no)$ ]]; then
                echo -e "${bold_red}Error: Invalid value for $param_name. Must be 'yes' or 'no'. Using recommended value.${reset}" >&2
                echo "$recommendation"
                return
            fi
            ;;
        *)
            # For any other parameters, just return the input value
            ;;
    esac

    echo "$value"
}

# Function to compare configs
compare_configs() {
    if [ -f /etc/ssh/sshd_config ]; then
        echo -e "\nComparing generated config with current config:"
        diff -u /etc/ssh/sshd_config sshd_config_generated.md || true
    else
        echo -e "\nCurrent SSH config file not found. Skipping comparison."
    fi
}

# Main function
main() {
    echo -e "${bold_blue}SSH Server Configuration Generator${reset}"
    echo -e "This script will guide you through the process of generating a secure SSH server configuration."
    echo -e "Please follow the prompts and provide the necessary information."
    echo -e ""
    check_sudo
    check_sshd
    echo -e ""
    echo -e "${bold_blue}How This Script Works:${reset}"
    echo -e "- Press 'Enter' for each parameter to use the recommended value."
    echo -e "- Press '!' to skip a parameter (it will not be added to the configuration)."
    echo -e ""
    select_params_file
    read_params
    generate_config
    echo -e "Configuration saved to ${bold_blue}sshd_config_generated.md${reset}"

    read -p "Do you want to check the generated config file? (y/n) > " -r choice
    [[ $choice =~ ^[Yy]$ ]] && check_generated_config

    compare_configs

    read -p "Do you want to overwrite /etc/ssh/sshd_config and restart SSH? (y/n) > " -r choice
    if [[ $choice =~ ^[Yy]$ ]]; then
        sudo cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.backup.$(date +%Y%m%d%H%M%S)"
        echo -e "Backup of original configuration created."
        
        sudo cp sshd_config_generated.md /etc/ssh/sshd_config
        restart_ssh
        echo -e "SSH configuration updated and SSH server restarted."
    fi

    read -p "Do you want to set ownership (root:root) and permissions (0600) on /etc/ssh/sshd_config? (y/n) > " -r set_permissions
    if [[ $set_permissions =~ ^[Yy]$ ]]; then
        sudo chown root:root /etc/ssh/sshd_config
        sudo chmod 0600 /etc/ssh/sshd_config
        echo -e "Ownership and permissions set on /etc/ssh/sshd_config."
    fi

    echo -e ""
    echo -e "${bold_blue}Great! Enjoy a more secure SSH server!${reset}"
    echo -e ""
}

main
