#!/bin/bash
set -euo pipefail

# ==============================
#  Default Settings
# ==============================
BROWSER="chromium"
BROWSER_FLAGS="--noerrdialogs --no-memcheck --no-first-run --start-maximized --disable-translate --disable-infobars --disable-suggestions-service --disable-save-password-bubble --disable-session-crashed-bubble"
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

# ==============================
#  Helpers
# ==============================
error_exit() { echo "Error: $1" >&2; exit 1; }
require_numeric() { [[ "$2" =~ ^[0-9]+$ ]] || error_exit "$1 must be numeric"; }

# ==============================
#  Argument Parsing
# ==============================
while [[ $# -gt 0 ]]; do
    case "$1" in
        --card)        require_numeric CARD "$2"; CARD="$2"; shift 2 ;;
        --device)      require_numeric DEVICE "$2"; DEVICE="$2"; shift 2 ;;
        --auto-reboot) require_numeric REBOOTMIN "$2"; AUTOREBOOT=1; REBOOTMIN="$2"; shift 2 ;;
        --browser)     
            case "$2" in
                chrome)   BROWSER="google-chrome-stable" ;;
                chromium) BROWSER="chromium" ;;
                brave)    BROWSER="brave-browser" ;;
                *) error_exit "Invalid browser: $2" ;;
            esac
            shift 2 ;;
        --url)         URL="$2"; shift 2 ;;
        --screen)      [[ "$2" =~ ^[0-9]{3,4}x[0-9]{3,4}$ ]] || error_exit "Invalid resolution"; SCREEN_RESOLUTION="$2"; shift 2 ;;
        --auto-refresh) require_numeric REFRESHSEC "$2"; REFRESHSEC="$2"; shift 2 ;;
        --incognito)   BROWSER_FLAGS+=" --incognito"; shift ;;
        --kiosk)       BROWSER_FLAGS+=" --kiosk"; shift ;;
        --auto-update) AUTOUPDATE=1; shift ;;
        --block-downloads) BLOCKDOWNLOADS=1; shift ;;
        --ad-block)    ADBLOCK=1; shift ;;
        --hide-cursor) HIDECURSOR=1; shift ;;
        *) error_exit "Unknown option: $1" ;;
    esac
done

# ==============================
#  System Setup
# ==============================
export DEBIAN_FRONTEND=noninteractive
apt-get update -y && apt-get upgrade -y
apt-get install -y sway xwayland alsa-utils sudo nftables curl wget

# ==============================
#  Install Browser
# ==============================
case $BROWSER in
    google-chrome-stable)
        wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
        apt-get install -y ./google-chrome-stable_current_amd64.deb
        rm -f ./google-chrome-stable_current_amd64.deb
        BROWSERPOLICY="opt/chrome"
        ;;
    chromium)
        apt-get install -y chromium
        BROWSERPOLICY="chromium"
        ;;
    brave-browser)
        curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | tee /etc/apt/sources.list.d/brave-browser-release.list
        apt-get update -y && apt-get install -y brave-browser
        BROWSERPOLICY="brave"
        ADBLOCK="" # Brave already has adblock
        ;;
esac

# ==============================
#  Browser Policies
# ==============================
mkdir -p /etc/${BROWSERPOLICY}/policies/managed
if [[ -n "$BLOCKDOWNLOADS" ]]; then
    cat > /etc/${BROWSERPOLICY}/policies/managed/download_policy.json <<EOL
{"DownloadRestrictions": 3, "DownloadDirectory": "/home/kiosk/Downloads"}
EOL
    chmod 644 /etc/${BROWSERPOLICY}/policies/managed/download_policy.json
fi

if [[ -n "$ADBLOCK" ]]; then
    cat > /etc/${BROWSERPOLICY}/policies/managed/adblock_policy.json <<EOL
{"ExtensionInstallForcelist":["ddkjiahejlhfcafbddmgiahcphecmpfh;https://clients2.google.com/service/update2/crx"]}
EOL
    chmod 644 /etc/${BROWSERPOLICY}/policies/managed/adblock_policy.json
fi

# ==============================
#  Browser Data Folder
# ==============================
install -d -o kiosk -g kiosk /home/kiosk/.config/kiosk-browser-data
BROWSER_FLAGS+=" --user-data-dir=/home/kiosk/.config/kiosk-browser-data"

# ==============================
#  Auto-Refresh Setup
# ==============================
if [[ -n "$REFRESHSEC" ]]; then
    BROWSER_FLAGS+=" --remote-debugging-port=9222 --remote-debugging-address=127.0.0.1"
    apt-get install -y nodejs npm
    npm install -g ws@latest
    NPMUPDATE=" && npm update -g"

    cat > /etc/systemd/system/kiosk-auto-refresh.service <<EOL
[Unit]
Description=Auto refresh browser
After=multi-user.target

[Service]
ExecStart=/usr/bin/node -e "const http=require('http'), WebSocket=require('ws'); http.get('http://localhost:9222/json', r=>{let d='';r.on('data',c=>d+=c);r.on('end',()=>{try{JSON.parse(d).forEach(p=>{if(p.webSocketDebuggerUrl){const ws=new WebSocket(p.webSocketDebuggerUrl);ws.on('open',()=>{ws.send(JSON.stringify({id:1,method:'Page.reload',params:{ignoreCache:true}}));ws.close();});}});}catch(e){console.error(e);}});}).on('error',e=>console.error(e));"
Restart=always
RestartSec=${REFRESHSEC}

[Install]
WantedBy=multi-user.target
EOL
    systemctl enable kiosk-auto-refresh.service
fi

# ==============================
#  Autologin + Kiosk Startup
# ==============================
install -d /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<EOL
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin kiosk --noclear %I \$TERM
EOL

cat > /home/kiosk/.startkiosk <<'EOL'
#!/bin/bash
clear; echo "Initializing Graphic Drivers..."
while ! ls /dev/dri | grep -q "card"; do sleep 1; done
clear; echo "Establishing Network Connection..."
while ! ip route | grep -q "^default"; do sleep 1; done
clear; export WLR_NO_HARDWARE_CURSORS=1
amixer -c ${CARD} sset Master 100%
clear; sway
EOL
chmod +x /home/kiosk/.startkiosk
grep -qxF "source /home/kiosk/.startkiosk" /home/kiosk/.bashrc || echo "source /home/kiosk/.startkiosk" >> /home/kiosk/.bashrc

# ==============================
#  Sway Config
# ==============================
install -d -o kiosk -g kiosk /home/kiosk/.config/sway
cat > /home/kiosk/.config/sway/config <<EOL
set \$mod none
for_window [class=".*"] border pixel 0
default_border none
output * resolution $SCREEN_RESOLUTION
input * xkb_layout gb
exec sh -c "$BROWSER $BROWSER_FLAGS $URL; sudo systemctl reboot"
EOL

if [[ -n "$HIDECURSOR" ]]; then
    sed -i '/^exec sh -c/ i seat seat0 hide_cursor 3000' /home/kiosk/.config/sway/config
fi

# ==============================
#  Audio Config
# ==============================
cat > /etc/asound.conf <<EOL
defaults.pcm.card $CARD
defaults.pcm.device $DEVICE
EOL

# ==============================
#  Auto-Reboot Setup
# ==============================
cat > /etc/systemd/system/kiosk-auto-reboot.service <<EOL
[Unit]
Description=Reboot System
[Service]
Type=simple
ExecStart=/usr/bin/systemctl reboot
EOL

cat > /etc/systemd/system/kiosk-auto-reboot.timer <<EOL
[Unit]
Description=Auto Reboot Every ${REBOOTMIN} Min(s)
[Timer]
OnBootSec=${REBOOTMIN}min
[Install]
WantedBy=timers.target
EOL

if [[ -n "$AUTOREBOOT" ]]; then
    systemctl enable kiosk-auto-reboot.timer
else
    systemctl disable kiosk-auto-reboot.timer
fi

# ==============================
#  Auto-Update Setup
# ==============================
cat > /etc/systemd/system/kiosk-auto-update.service <<EOL
[Unit]
Description=Update System
Wants=network-online.target
After=network-online.target
[Service]
Type=simple
ExecStart=/bin/bash -c "apt-get update -y && apt-get upgrade -y${NPMUPDATE}"
ExecStop=/bin/bash -c 'sleep 2 && echo "Installing Updates..." > /dev/tty1 && while kill -0 \$MAINPID; do sleep 1; done'
TimeoutSec=3600
TimeoutStopSec=3600
EOL

cat > /etc/systemd/system/kiosk-auto-update.timer <<EOL
[Unit]
Description=Auto System Updates Weekly
[Timer]
OnCalendar=weekly
Persistent=true
[Install]
WantedBy=timers.target
EOL

if [[ -n "$AUTOUPDATE" ]]; then
    systemctl enable kiosk-auto-update.timer
else
    systemctl disable kiosk-auto-update.timer
fi

# ==============================
#  Security + Firewall
# ==============================
cat > /etc/sudoers.d/kiosk-reboot <<EOL
kiosk ALL=(ALL) NOPASSWD:/usr/bin/systemctl reboot
EOL
chmod 440 /etc/sudoers.d/kiosk-reboot

cat > /etc/nftables.conf <<'EOL'
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

# ==============================
#  Bootloader
# ==============================
sed -i 's/^GRUB_TIMEOUT=[0-9]*$/GRUB_TIMEOUT=0/' /etc/default/grub
update-grub

# ==============================
#  Final Step
# ==============================
reboot
