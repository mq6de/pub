#!/bin/bash
set -e  # Stop script on error

### CONFIGURABLE VARIABLES ###
ROOT_PASSWORD=""  # Set manually or leave empty to prompt
GITHUB_USERNAME="mq6de"  # Change this to your GitHub username
LOG_FILE="/var/log/setup_script.log"
MAIL_TO=""  # Set recipient email (leave empty to log locally)
MAIL_FROM="ubuntu@yourserver.com"
SMTP_SERVER="smtp.yourserver.com"
SMTP_PORT="587"
SMTP_USER="your-email-username"
SMTP_PASS="your-email-password"

### FUNCTION: Logging setup ###
exec > >(tee -a "$LOG_FILE") 2>&1
echo "Log file: $LOG_FILE"
if [[ -z "$MAIL_TO" ]]; then
    echo "No email configured. Logs will be stored locally at $LOG_FILE."
fi
echo "Starting setup..."

### FUNCTION: Change Root Password ###
change_root_password() {
    echo "Changing root password..."
    if [[ -z "$ROOT_PASSWORD" ]]; then
        read -sp "Enter new root password: " ROOT_PASSWORD
        echo
    fi
    echo "root:$ROOT_PASSWORD" | sudo chpasswd
    echo "Root password changed."
}

### FUNCTION: Install Essential Packages ###
install_packages() {
    echo "Installing essential packages..."
    sudo apt update && sudo apt install -y nano ufw
}

### FUNCTION: Configure Firewall (UFW) ###
configure_firewall() {
    echo "Setting up UFW firewall..."
    sudo ufw allow OpenSSH
    sudo ufw enable
}

### FUNCTION: Auto-import SSH Key from GitHub ###
import_ssh_key() {
    echo "Importing SSH key from GitHub for user: $GITHUB_USERNAME..."
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    curl -s "https://github.com/$GITHUB_USERNAME.keys" >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    echo "SSH key imported successfully."
}

### FUNCTION: Send Log via Email ###
send_log_via_email() {
    if [[ -n "$MAIL_TO" ]]; then
        echo "Sending log via SMTP API..."
        RESPONSE=$(curl --url "smtps://$SMTP_SERVER:$SMTP_PORT" --ssl-reqd \
            --mail-from "$MAIL_FROM" --mail-rcpt "$MAIL_TO" \
            --user "$SMTP_USER:$SMTP_PASS" \
            --upload-file "$LOG_FILE" 2>&1)

        if [[ $? -eq 0 ]]; then
            echo "Email sent successfully to $MAIL_TO."
        else
            echo "Failed to send email. Curl error:"
            echo "$RESPONSE"
        fi
    else
        echo "Email not configured. Log stored locally at $LOG_FILE."
    fi
}


### FUNCTION: Perform System Reboot ###
reboot_system() {
    echo "Setup complete! Rebooting in 10 seconds..."
    sleep 10
    sudo reboot
}

### EXECUTE FUNCTIONS ###
change_root_password
install_packages
configure_firewall
import_ssh_key
send_log_via_email
reboot_system
