#!/bin/bash
set -euo pipefail

# Script Settings/Arguments
BROWSER="chromium"
BROWSER_FLAGS="--noerrdialogs --no-memcheck --no-first-run --start-maximized --disable --disable-translate --disable-infobars --disable-suggestions-service --disable-save-password-bubble --disable-session-crashed-bubble"
URL=""
CARD="0"
DEVICE="0"
SCREEN_RESOLUTION="1920x1080"
AUTOREBOOT=""
REBOOTMIN="60"
AUTOUPDATE=""
BLOCKDOWNLOADS=""
ADBLOCK=""
HIDECURSOR=""
REFRESHSEC=""
NPMUPDATE=""

# --- Helpers ---
usage() {
    cat >&2 <<EOF
Usage: $0 [options]

Options:
  --card X             Audio card number
  --device X           Device number
  --screen WxH         Screen resolution (e.g., 1920x1080)
  --browser            {chrome|chromium|brave}
  --url URL            Page to load
  --auto-refresh SEC   Auto-refresh interval (seconds)
  --auto-reboot MIN    Auto-reboot interval (minutes)
  --auto-update        Enable auto-updates
  --incognito          Launch in incognito mode
  --kiosk              Launch in kiosk mode
  --block-downloads    Block file downloads
  --ad-block           Enable ad-block
  --hide-cursor        Hide mouse cursor
EOF
    exit 1
}

require_number() {
    [[ "$2" =~ ^[0-9]+$ ]] || { echo "Error: $1 must be a number" >&2; exit 1; }
}

require_resolution() {
    [[ "$1" =~ ^[0-9]{3,4}x[0-9]{3,4}$ ]] || { echo "Error: Invalid resolution: $1" >&2; exit 1; }
}

# --- Parse command-line arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --card)          require_number CARD "${2:-}"; CARD="$2"; shift 2 ;;
        --device)        require_number DEVICE "${2:-}"; DEVICE="$2"; shift 2 ;;
        --auto-reboot)   require_number "auto-reboot" "${2:-}"; AUTOREBOOT=REBOOT; REBOOTMIN="$2"; shift 2 ;;
        --browser)       case "${2:-}" in
                            chrome) BROWSER="google-chrome-stable" ;;
                            chromium) BROWSER="chromium" ;;
                            brave) BROWSER="brave-browser" ;;
                            *) echo "Invalid browser: $2" >&2; exit 1 ;;
                         esac; shift 2 ;;
        --url)           URL="$2"; shift 2 ;;
        --screen)        require_resolution "${2:-}"; SCREEN_RESOLUTION="$2"; shift 2 ;;
        --auto-refresh)  require_number "auto-refresh" "${2:-}"; REFRESHSEC="$2"; shift 2 ;;
        --incognito)     BROWSER_FLAGS+=" --incognito"; shift ;;
        --kiosk)         BROWSER_FLAGS+=" --kiosk"; shift ;;
        --auto-update)   AUTOUPDATE="UPDATE"; shift ;;
        --block-downloads) BLOCKDOWNLOADS="BLOCK"; shift ;;
        --ad-block)      ADBLOCK="INSTALL"; shift ;;
        --hide-cursor)   HIDECURSOR="HIDE"; shift ;;
        *)               usage ;;
    esac
done

# Update the system & Install packages
apt update -y
apt upgrade -y
apt install -y sway xwayland alsa-utils sudo

# Install selected browser
case $BROWSER in
    google-chrome-stable)
        wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
        apt install -y ./google-chrome-stable_current_amd64.deb
        rm -f ./google-chrome-stable_current_amd64.deb
        BROWSERPOLICY="opt/chrome"
        ;;
    chromium)
        apt install -y chromium
        BROWSERPOLICY="chromium"
        ;;
    brave-browser)
        apt install curl -y
        curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | tee /etc/apt/sources.list.d/brave-browser-release.list
        apt update -y 
        apt install brave-browser -y
        BROWSERPOLICY="brave"
        ADBLOCK=""
        ;;
esac

# Set Browser Policies
if [ -n "$BLOCKDOWNLOADS" ]; then
    mkdir -p /etc/${BROWSERPOLICY}/policies/managed
    echo '{"DownloadRestrictions": 3, "DownloadDirectory": "/home/${user_name}/Downloads"}' | tee /etc/${BROWSERPOLICY}/policies/managed/download_policy.json
    chmod 644 /etc/${BROWSERPOLICY}/policies/managed/download_policy.json
fi
if [ -n "$ADBLOCK" ]; then
    mkdir -p /etc/${BROWSERPOLICY}/policies/managed
    echo '{"ExtensionInstallForcelist":["ddkjiahejlhfcafbddmgiahcphecmpfh;https://clients2.google.com/service/update2/crx"]}' | tee /etc/${BROWSERPOLICY}/policies/managed/adblock_policy.json
    chmod 644 /etc/${BROWSERPOLICY}/policies/managed/adblock_policy.json
fi

#Set browser data folder
mkdir -p "/home/kiosk/.config/kiosk-browser-data"
chown kiosk:kiosk "/home/kiosk/.config/kiosk-browser-data"
BROWSER_FLAGS="$BROWSER_FLAGS --user-data-dir=/home/kiosk/.config/kiosk-browser-data"

if [ -n "$REFRESHSEC" ]; then
# Configure browser to launch with debugging enabled
BROWSER_FLAGS="$BROWSER_FLAGS --remote-debugging-port=9222 --remote-debugging-address=127.0.0.1"

# Install dependencies for browser debugging communication
apt install -y nodejs npm
npm install -g ws@latest
NPMUPDATE=" && npm update -g"

# Create auto-refresh service
cat > /etc/systemd/system/kiosk-auto-refresh.service <<EOL
[Unit]
Description=Auto refresh browser
After=multi-user.target

[Service]
ExecStart=/usr/bin/node -e "const http=require(\"http\"), WebSocket=require(\"ws\"); http.get(\"http://localhost:9222/json\", r => { let d=\"\"; r.on(\"data\", c => d+=c); r.on(\"end\", () => { try { JSON.parse(d).forEach(p => { if(p.webSocketDebuggerUrl){ const ws=new WebSocket(p.webSocketDebuggerUrl); ws.on(\"open\", () => { ws.send(JSON.stringify({id:1,method:\"Page.reload\",params:{ignoreCache:true}})); ws.close(); }); } }); } catch(e){ console.error(e); } }); }).on(\"error\", e => console.error(e));"
Restart=always
RestartSec=${REFRESHSEC}

[Install]
WantedBy=multi-user.target
EOL

# Enable refresh service
systemctl enable kiosk-auto-refresh.service
fi

# Create the directory for the systemd service override
mkdir -p /etc/systemd/system/getty@tty1.service.d/

# Create the override.conf file
cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<EOL
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin kiosk --noclear %I \$TERM
EOL

# Create the .startkiosk file
cat > /home/kiosk/.startkiosk <<EOL
#!/bin/bash
clear
echo "Initializing Graphic Drivers..."
while ! ls /dev/dri | grep -q "card"; do
    sleep 1
done
clear
echo "Establishing Network Connection..."
while ! ip route | grep -q "^default"; do
    sleep 1
done
clear
export WLR_NO_HARDWARE_CURSORS=1 wio
amixer -c ${CARD} sset Master 100%
clear
sway
EOL

# Make .startkiosk executable
chmod +rx /home/kiosk/.startkiosk

# Add ".startkiosk file to bashrc (if not already)
grep -qxF "source /home/kiosk/.startkiosk" /home/kiosk/.bashrc || echo "source /home/kiosk/.startkiosk" >> /home/kiosk/.bashrc

# Create the directory for the sway config
mkdir -p /home/kiosk/.config/sway
chown kiosk:kiosk /home/kiosk/.config

# Make sway config file
cat > /home/kiosk/.config/sway/config <<EOL
set \$mod none
for_window [class=".*"] border pixel 0
default_border none
output * resolution $SCREEN_RESOLUTION
input * xkb_layout gb
exec sh -c "$BROWSER$BROWSER_FLAGS$URL; sudo systemctl reboot"
EOL

# Hide mouse cursor if command-line argument is provided.
if [ -n "$HIDECURSOR" ]; then
    sed -i '/^exec sh -c/ i seat seat0 hide_cursor 3000' /home/kiosk/.config/sway/config
fi

# Make asound.conf for audio settings
cat > /etc/asound.conf <<EOL
defaults.pcm.card $CARD
defaults.pcm.device $DEVICE
EOL

# Make auto reboot service
cat > /etc/systemd/system/kiosk-auto-reboot.service <<EOL
[Unit]
Description=Reboot System

[Service]
Type=simple
ExecStart=/usr/bin/systemctl reboot
EOL

# Make auto reboot timer
cat > /etc/systemd/system/kiosk-auto-reboot.timer <<EOL
[Unit]
Description=Auto Reboot Every ${REBOOTMIN} Min(s)

[Timer]
OnBootSec=${REBOOTMIN}min

[Install]
WantedBy=timers.target
EOL

# Enable/Disable reboot task
if [ -z "$AUTOREBOOT" ]; then
    systemctl disable kiosk-auto-reboot.timer
else
    systemctl enable kiosk-auto-reboot.timer
fi

# Make auto update service
cat > /etc/systemd/system/kiosk-auto-update.service <<EOL
[Unit]
Description=Update System
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=/bin/bash -c "apt update -y && apt upgrade -y${NPMUPDATE}"
ExecStop=/bin/bash -c 'sleep 2 && echo "Installing Updates..." > /dev/tty1 && while kill -0 \$MAINPID; do sleep 1; done'
TimeoutSec=3600
TimeoutStopSec=3600
EOL

# Make auto update timer
cat > /etc/systemd/system/kiosk-auto-update.timer <<EOL
[Unit]
Description=Auto System Updates Every Week

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOL

# Enable/Disable system update task
if [ -z "$AUTOUPDATE" ]; then
    systemctl disable kiosk-auto-update.timer
else
    systemctl enable kiosk-auto-update.timer
fi

# Allow kiosk user to reboot the system
cat > /etc/sudoers.d/kiosk-reboot <<EOL
kiosk ALL=(ALL) NOPASSWD:/usr/bin/systemctl reboot
EOL

# Create and enable firewall (nftables)
cat > /etc/nftables.conf <<EOL
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;
    iifname lo accept;
    ct state {established, related} accept;
  }
  chain forward {
    type filter hook forward priority 0; policy drop;
  }
  chain output {
    type filter hook output priority 0; policy accept;
  }
}
EOL
systemctl enable nftables

# Update GRUB configuration
sed -i 's/^GRUB_TIMEOUT=[0-9]*$/GRUB_TIMEOUT=0/' /etc/default/grub
update-grub

# Reboot system
reboot
