#!/bin/bash

# Define color variables
bold_blue="\e[1;34m"
bold_green="\e[1;32m"
bold_red="\e[1;31m"
reset="\e[0m"

# Function to check if sudo command is available and if the user has sudo privileges
check_sudo() {
    if ! command -v sudo &> /dev/null; then
        echo -e "${bold_red}Error: sudo command not found.${reset}"
        exit 1
    fi

    if ! sudo -n true 2>/dev/null; then
        echo -e "${bold_red}Error: You do not have sudo privileges or a password is required (try with: sudo ./sshield.sh).${reset}"
        exit 1
    fi
}


# Function to check if sshd command is available and install OpenSSH server if not found
check_sshd() {
    if ! command -v sshd &> /dev/null; then
        echo -e "${bold_red}Error: sshd command not found.${reset}"
        read -p "Do you want to install OpenSSH server? (y/n) > " -r choice
        if [[ $choice =~ ^[Yy]$ ]]; then
            if command -v apt-get &> /dev/null; then
                sudo apt-get install openssh-server || { echo -e "${bold_red}Error: Failed to install OpenSSH server.${reset}"; exit 1; }
            elif command -v yum &> /dev/null; then
                sudo yum install openssh-server || { echo -e "${bold_red}Error: Failed to install OpenSSH server.${reset}"; exit 1; }
            elif command -v dnf &> /dev/null; then
                sudo dnf install openssh-server || { echo -e "${bold_red}Error: Failed to install OpenSSH server.${reset}"; exit 1; }
            else
                echo -e "${bold_red}Error: Unsupported package manager.${reset}"
                exit 1
            fi
        else
            echo -e "${bold_red}Error: sshd command is required.${reset}"
            exit 1
        fi
    fi
}

# Function to select a params file
select_params_file() {
    local options=()
    local choice

    echo -e "Parameters available:"
    local files=(configs/*)
    for i in "${!files[@]}"; do
        local filename=$(basename "${files[i]}")
        local comment=$(sed -n '1s/^# *//p' "${files[i]}")
        options+=("$comment")
        echo -e "[$i] ${bold_blue}$comment${reset}"
    done

    echo -e ""
    read -p "Select the option you want > " choice
    echo -e ""

    if [[ ! $choice =~ ^[0-9]+$ ]] || ((choice < 0 || choice >= ${#options[@]})); then
        echo -e "${bold_red}Invalid choice. Please retry with a valid option.${reset}"
        exit 1
    fi

    params_file="${files[choice]}"

    if [ ! -f "$params_file" ]; then
        echo "Parameter file '$params_file' not found..."
        exit 1
    fi
}

# Function to read parameters from an external file
read_params() {
    if [ -f "$params_file" ]; then
        mapfile -t params < <(sed '/^#/d' "$params_file") # Ignore lines starting with #
    
        for line in "${params[@]}"; do
            if [[ ! $line =~ ^[^:]+:[^:]+:[^:]+$ ]]; then 
                echo "Invalid format in params files $params_file"
                exit 1
            fi
        done
    else
        echo "Parameter file '$params_file' not found."
        exit 1
    fi
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
    fi

    echo "$value"
}

# Function to generate the SSH server configuration
generate_config() {
    local config=""
    config+="Include /etc/ssh/sshd_config.d/*.conf\n\n"
    for param_info in "${params[@]}"; do
        local value=$(create_field "$param_info")
        if [ "$value" != "!" ]; then
            config+="# ${param_info#*:}\n"
            config+="${param_info%%:*} $value\n\n"
        fi
        echo >&2
    done
    echo -e "$config" >sshd_config_generated.md
}

# Function to check the generated configuration for errors
check_generated_config() {
        if ! sshd -t -f sshd_config_generated.md; then
            echo -e "${bold_red}Error: There is a problem with the generated configuration. Please check sshd_config_generated.md${reset}"
            exit 1
        fi
}

# Function to restart SSH based on the Linux distribution
restart_ssh() {
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        case "$ID" in
        debian | ubuntu)
            if ! sudo service ssh restart; then
                echo -e "${bold_red}Failed to restart SSH. You may need to do it manually.${reset}"
            fi
            ;;
        centos | rhel | fedora)
            if ! sudo systemctl restart sshd; then
                echo -e "${bold_red}Failed to restart SSH. You may need to do it manually.${reset}"
            fi
            ;;
        alpine)
            if ! sudo rc-service sshd restart; then
                echo -e "${bold_red}Failed to restart SSH. You may need to do it manually.${reset}"
            fi
            ;;
        *)
            echo -e "${bold_red}Unsupported Linux distribution. You may need to manually restart SSH.${reset}"
            ;;
        esac
    else
        echo -e "${bold_red}Unable to determine the Linux distribution. You may need to manually restart SSH.${reset}"
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
    echo -e "${bold_blue}How This Script Works :${reset}"
    echo -e "- Press 'Enter' for each parameter to use the recommended value."
    echo -e "- Press '!' to skip a parameter (it will not be added to the configuration)."
    echo -e ""
    select_params_file
    read_params
    local config=$(generate_config)
    echo -e "${bold_green}$config${reset}"
    echo -e "Configuration saved to ${bold_blue}sshd_config_generated.txt${reset}"

    check_generated_config

    read -p "Do you want to overwrite /etc/ssh/sshd_config and restart SSH? (y/n) > " -r choice
    if [[ $choice =~ ^[Yy]$ ]]; then
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
