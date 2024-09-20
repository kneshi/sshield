# SSHield

SSHield is a Bash script that helps you secure your SSH server by generating a configuration based on your preferences and best practices.

⚠️ **WARNING**: Always review the generated configuration before applying it to your system. SSH configuration depends on various factors including the specific use case, network environment, and organizational policies. Use this script with care. ⚠️

## Features

- Interactive configuration generation
- Support for multiple configuration templates (CIS Debian 11, ANSSI)
- Validation of user input with improved error handling
- Automatic backup of existing SSH configuration
- Option to set correct ownership and permissions on the SSH config file
- Comparison between current and generated configurations

## Sources

The recommendations for the parameter values are based on the following sources:

- ANSSI (2015): [French Security Agency Recommendations](https://www.ssi.gouv.fr/guide/recommandations-pour-un-usage-securise-dopenssh/)
- CIS Debian 11: [Center for Internet Security Recommendations - Debian 11](https://downloads.cisecurity.org/#/)

## How It Works

SSHield reads parameter information from the `configs/` directory. Each parameter consists of a name, comment, and recommended value. You will be prompted to enter your preferred value for each parameter.

The generated configuration is saved to `sshd_config_generated.md`. Optionally, you can choose to overwrite `/etc/ssh/sshd_config` and restart the SSH server.

## Usage

1. Clone the repository: `git clone https://github.com/kneshi/sshield.git`
2. Navigate to the cloned directory: `cd sshield`
3. Make the script executable: `chmod +x sshield.sh`
4. Run the script: `sudo ./sshield.sh`

Note: The script requires sudo privileges to modify the SSH configuration and restart the SSH service.

## Requirements

- Bash shell
- sudo privileges
- OpenSSH server installed (the script can help you install it if it's missing)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Completed Tasks

- [x] Populate configs files
- [x] Test /usr/sbin/sshd -t -f
- [x] Set mode and ownership on the sshd_config file if pushed to prod (root:root and 0600)
- [x] Add a mandatory option to be sure we don't forget a parameter
- [x] Improve input validation for SSH parameters
- [x] Enhance error handling and user feedback

## Todo

- [x] Push to git
- [ ] Add more comprehensive logging
- [ ] Implement unit tests for the script functions
- [ ] Add support for more Linux distributions
- [ ] Create a configuration file for the script itself (e.g., default paths, behavior options)
- [ ] Implement a rollback feature in case of configuration errors
- [ ] Add support for custom SSH parameters not included in the default configs
