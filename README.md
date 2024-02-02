# SSHield
⚠️ WARNING: Configuration contains random data for testing purposes only. SSH configuration depends on various factors including the specific use case, network environment, and organizational policies, so, use this script with care. ⚠️

SSHield is a script that helps you secure your SSH server by generating a configuration based on your preferences.

## Sources

The recommendations for the parameter values are based on the following sources:

- ANSSI (2015): [French Security Agency Recommendations](https://www.ssi.gouv.fr/guide/recommandations-pour-un-usage-securise-dopenssh/)
- CIS Debian 11: [Center for Internet Security Recommendations - Debian 11](https://downloads.cisecurity.org/#/)

## How It Works

SSHield reads parameter information from the `configs/` directory. Each parameter consists of a name, comment, and recommended value. You will be prompted to enter your preferred value for each parameter.

The generated configuration is saved to `sshd_config_generated.txt`. Optionally, you can choose to overwrite `/etc/ssh/sshd_config` and restart the SSH server.

## Usage

1. Clone the repository: `git clone https://github.com/kneshi/sshield.git`
2. Navigate to the cloned directory: `cd sshield`
3. Run the script: `./sshield.sh`

## Todo

- [ ] Populate configs files
- [ ] Test /usr/sbin/sshd -t -f
- [ ] Set mode and ownership on the sshd_config file if pushed to prod (root:root and 0600)
- [ ] Add a mandatory option to be sure we don't forget a parameter