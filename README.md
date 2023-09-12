# SSH Server Configuration Generator

This script generate an SSH server configuration based on recommendations from either ANSSI (French Security Agency) or CIS (Center for Internet Security).

## Running the Script

1. `chmod +x sshield.sh`
2. `./sshield.sh`

## Parameter Sets

- ANSSI: French Security Agency Recommendations
- CIS: Center for Internet Security Recommendations

## How It Works

This script reads parameter information from `configs/` directory.
Each parameter consists of a name, comment, and recommended value.
You will be prompted to enter your preferred value for each parameter.

The generated configuration is saved to `sshd_config_generated.txt`.
Optionally, you can choose to overwrite `/etc/ssh/sshd_config` and restart the SSH server.

## Todo

- [ ] populate configs files
- [ ] test /usr/sbin/sshd -t -f
