#!/bin/bash

# Update the system
apt update -y
apt upgrade -y
apt install -y weston alsa-utils sudo chromium

# Create the directory for the systemd service override
mkdir -p /etc/systemd/system/getty@tty1.service.d/

# Create the override.conf file
cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<EOL
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin kiosk --noclear %I \$TERM
EOL

# Create the .kioskstartx file
cat > /home/kiosk/.kioskweston <<EOL
#!/bin/bash
clear
sleep 5
weston
EOL

# Make .xinitrc owned by the kiosk user and executable
chown kiosk:kiosk /home/kiosk/.kioskweston
chmod +x /home/kiosk/.kioskweston

# Add ".kioskstartx file to bashrc (if not already)
grep -qxF "source /home/kiosk/.kioskweston" /home/kiosk/.bashrc || echo "source /home/kiosk/.kioskweston" >> /home/kiosk/.bashrc

# Allow kiosk user to reboot system
cat > /etc/sudoers.d/kiosk <<EOL
kiosk ALL=(ALL) NOPASSWD:/bin/systemctl reboot
EOL

# Update GRUB configuration
sed -i 's/^GRUB_TIMEOUT=[0-9]*$/GRUB_TIMEOUT=0/' /etc/default/grub
update-grub

# Reboot system
reboot
