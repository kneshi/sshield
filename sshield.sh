#!/bin/bash

# Define color variables
bold_blue="\e[1;34m"
bold_green="\e[1;32m"
reset="\e[0m"

# Select params file
choose_params_file() {
    local options=()
    local choice

    echo -e "Parameters available:"
    local files=(configs/*)
    for i in "${!files[@]}"; do
        local filename=$(basename "${files[i]}")
        local comment=$(sed -n '1s/^# *//p' "${files[i]}")  # Extract and remove leading '#' from comment
        options+=("$comment")
        echo -e "[$i] ${bold_blue}$comment${reset}"
    done

    echo -e ""
    read -p "Select the option you want > " choice
    echo -e ""

    if [[ ! $choice =~ ^[0-9]+$ ]] || ((choice < 0 || choice >= ${#options[@]})); then
        echo "Invalid choice. Please retry with a valid option."
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
        mapfile -t params < <(sed '/^#/d' "$params_file")  # Ignore lines starting with #
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

# Function to generate the configuration
generate_config() {
    local config=""
    config+="Include /etc/ssh/sshd_config.d/*.conf\n\n"
    for param_info in "${params[@]}"; do
        local value=$(create_field "$param_info")
        config+="$(echo "$param_info" | cut -d ':' -f 1) $value\n"
        echo >&2
    done
    echo -e "$config" >sshd_config_generated.txt

    # Check the generated config - TODO : check this function
    # if ! /usr/sbin/sshd -t -f sshd_config_generated.txt; then
    #     echo "Error: There is a problem with the generated configuration. Please check sshd_config_generated.txt."
    #     exit 1
    # fi

}

# Function to restart SSH based on the Linux distribution
restart_ssh() {
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        case "$ID" in
        debian | ubuntu)
            sudo service ssh restart || echo "Failed to restart SSH. You may need to do it manually."
            ;;
        centos | rhel | fedora)
            sudo systemctl restart sshd || echo "Failed to restart SSH. You may need to do it manually."
            ;;
        *)
            echo "Unsupported Linux distribution. You may need to manually restart SSH."
            ;;
        esac
    else
        echo "Unable to determine the Linux distribution. You may need to manually restart SSH."
    fi
}

# Main function
main() {
    echo -e "${bold_blue}SSH Server Configuration Generator${reset}"
    echo -e "This script will help you generate an SSH server configuration."
    echo -e "You can press Enter for each parameter to use the recommended value."
    echo -e ""
    choose_params_file
    read_params
    local config=$(generate_config)
    echo -e "${bold_green}$config${reset}"
    echo -e "Configuration saved to ${bold_blue}sshd_config_generated.txt${reset}"

    read -p "Do you want to overwrite /etc/ssh/sshd_config and restart SSH? (y/n) > " -r choice
    if [[ $choice =~ ^[Yy]$ ]]; then
        sudo cp sshd_config_generated.txt /etc/ssh/sshd_config
        restart_ssh
        echo -e "SSH configuration updated and SSH server restarted."
    fi
    echo -e ""
    echo -e "${bold_blue}Great! Enjoy a more secure SSH server!${reset}"
    echo -e ""
}

main
