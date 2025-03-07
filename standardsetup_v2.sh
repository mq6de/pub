#!/bin/bash

### CONFIGURABLE VARIABLES ###
ROOT_PASSWORD=""  # Set manually or leave empty to prompt
GITHUB_USERNAME=""  # Change this to your GitHub username

### WIREGUARD VARIABLES ###
SERVER="dein.server.adresse"           # Die IP-Adresse oder der Hostname des WireGuard-Servers
PORT="51820"                            # Der Port, auf dem der WireGuard-Server lauscht
SERVER_PUBLIC_KEY="deinServerPublicKey" # Der öffentliche Schlüssel des WireGuard-Servers
CLIENT_PRIVATE_KEY=$(wg genkey)         # Erzeugt den privaten Schlüssel des Clients
CLIENT_IP="10.11.1.3/24"                # IP Adresse incl. subnetmask
CLIENT_PUBLIC_KEY=$(echo $CLIENT_PRIVATE_KEY | wg pubkey) # Der öffentliche Schlüssel des Clients

### EXECUTE FUNCTIONS ###
change_root_password
install_packages
configure_firewall
import_ssh_key
configure_firewall
reboot_system

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
    sudo apt update && sudo apt install -y nano ufw wireguard
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

### FUNCTION: Perform System Reboot ###
reboot_system() {
    echo "Setup complete! Rebooting in 10 seconds..."
    sleep 10
    sudo reboot
}

### FUNCTION: Configure Firewall (UFW) ###
configure_firewall() {
    echo "Setting up UFW firewall..."
    sudo ufw allow OpenSSH
    sudo ufw enable
}

### FUNCTION: Configure Wireguard ###
configure_wg() {

# Speichern des öffentlichen Schlüssels des Clients in einer Datei
echo $CLIENT_PUBLIC_KEY > /etc/wireguard/client_public_key.txt
echo "Der öffentliche Schlüssel des Clients wurde in /etc/wireguard/client_public_key.txt gespeichert."

# Konfiguration erstellen (wg0.conf)
echo "[Interface]" > /etc/wireguard/wg0.conf
echo "PrivateKey = $CLIENT_PRIVATE_KEY" >> /etc/wireguard/wg0.conf
echo "Address = $CLIENT_IP" >> /etc/wireguard/wg0.conf  # Beispiel IP-Adresse für den Client (anpassen!)
echo "" >> /etc/wireguard/wg0.conf
echo "[Peer]" >> /etc/wireguard/wg0.conf
echo "PublicKey = $SERVER_PUBLIC_KEY" >> /etc/wireguard/wg0.conf
echo "Endpoint = $SERVER:$PORT" >> /etc/wireguard/wg0.conf
echo "AllowedIPs = 0.0.0.0/0" >> /etc/wireguard/wg0.conf   # Alle IPs für das Routing durch den Tunnel
echo "PersistentKeepalive = 25" >> /etc/wireguard/wg0.conf # Optional: Verhindert, dass der Tunnel nach einer Inaktivität geschlossen wird

# UFW konfigurieren
ufw allow $PORT/udp       # Erlaubt den WireGuard-Port
ufw allow in on wg0        # Erlaubt Verkehr über das WireGuard-Interface
ufw enable                 # UFW aktivieren, falls noch nicht geschehen

# WireGuard starten
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

echo "WireGuard-Client wurde erfolgreich eingerichtet und gestartet."

}