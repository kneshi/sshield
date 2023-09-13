# SSH Server Configuration Generator

This script generate an SSH server configuration based on recommendations from either ANSSI (French Security Agency) or CIS (Center for Internet Security).

## Running the Script

1. `chmod +x sshield.sh`
2. `./sshield.sh`

## Parameter Sets

- ANSSI: [French Security Agency Recommendations](https://www.ssi.gouv.fr/guide/recommandations-pour-un-usage-securise-dopenssh/)
- CIS Debian 11: [Center for Internet Security Recommendations - Debian 11](https://downloads.cisecurity.org/#/)

## How It Works

This script reads parameter information from `configs/` directory.
Each parameter consists of a name, comment, and recommended value.
You will be prompted to enter your preferred value for each parameter.

The generated configuration is saved to `sshd_config_generated.txt`.
Optionally, you can choose to overwrite `/etc/ssh/sshd_config` and restart the SSH server.

## Todo

- [ ] populate configs files
- [ ] test /usr/sbin/sshd -t -f
- [ ] set mode and ownership on the sshd_config file if pushed to prod (root:root and 0600)
