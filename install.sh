#!/bin/bash

# Script Settings/Arguments
BROWSER="chromium"
BROWSER_FLAGS=""
URL=""
CARD="0"
DEVICE="0"
SCREEN_TEARING=" --set TearFree on"
SCREEN_RESOLUTION="1920x1080"
STARTXCMD="startx"
AUTOREBOOT=""
REBOOTMIN="60"
AUTOUPDATE=""
BLOCKDOWNLOADS=""
SSH=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --card)
            if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                echo "Error: CARD must be a number" >&2
                exit 1
            fi
            CARD="$2"
            shift 2
            ;;
            
        --device)
            if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                echo "Error: DEVICE must be a number" >&2
                exit 1
            fi
            DEVICE="$2"
            shift 2
            ;;

        --auto-reboot)
            if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                echo "Error: The --auto-reboot option requires a numeric value in minutes to specify the reboot delay after boot" >&2
                exit 1
            fi
            AUTOREBOOT="REBOOT"
            REBOOTMIN="$2"
            shift 2
            ;;
            
        --browser)
            if [[ ! "$2" =~ ^(chrome|chromium|brave)$ ]]; then
                echo "Invalid browser specified. Must be either 'chrome', 'chromium' or 'brave'" >&2
                exit 1
            fi
            # Set google-chrome-stable for chrome option
            if [[ "$2" == "chrome" ]]; then
                BROWSER="google-chrome-stable"
            # Set brave-browser for brave option
            elif [[ "$2" == "brave" ]]; then
                BROWSER="brave-browser"
            else
                BROWSER="chromium-browser"
            fi
            shift 2
            ;;
            
        --url)
            URL=" $2"
            shift 2
            ;;
     
        --screen)
            if ! [[ "$2" =~ ^[0-9]{3,4}x[0-9]{3,4}$ ]]; then
                echo "Error: SCREEN must be a screen resolution eg 1920x1080" >&2
                exit 1
            fi
            SCREEN_RESOLUTION="$2"
            shift 2
            ;;
            
        --incognito)
            BROWSER_FLAGS="$BROWSER_FLAGS --incognito"
            shift
            ;;
        
        --kiosk)
            BROWSER_FLAGS="$BROWSER_FLAGS --kiosk"
            shift
            ;;

        --no-cursor)
            STARTXCMD="startx -- -nocursor"
            shift
            ;;

        --no-tearfree)
            SCREEN_TEARING=""
            shift
            ;;

        --auto-update)
            AUTOUPDATE="UPDATE"
            shift
            ;;

        --block-downloads)
            BLOCKDOWNLOADS="BLOCK"
            shift
            ;;

        --keep-ssh)
            SSH="KEEP"
            shift
            ;;
            
        *)
            echo "Usage: $0 [--card X] [--device X] [--screen X] [--browser X] [--url X] [--auto-reboot X] [--auto-update] [--nourl] [--incognito] [--kiosk] [--keep-ssh] [--no-cursor] [--no-tearfree]" >&2
            exit 1
            ;;
    esac
done

if [ -z "$SSH" ]; then
    #disable SSH
    systemctl disable --now sshd
    dnf remove openssh-server -y
fi

# Update the system
dnf upgrade -y
dnf group install "Hardware Support" -y --setopt=install_weak_deps=false
dnf group install "base-x" -y --setopt=install_weak_deps=false
dnf install alsa-utils -y --setopt=install_weak_deps=false

case $BROWSER in
    google-chrome-stable)
        wget https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
        dnf install -y ./google-chrome-stable_current_x86_64.rpm --setopt=install_weak_deps=false
        rm -f ./google-chrome-stable_current_x86_64.rpm
        if [ -n "$BLOCKDOWNLOADS" ]; then
            mkdir -p /etc/opt/chrome/policies/managed
            echo '{"DownloadRestrictions": 3}' | sudo tee /etc/opt/chrome/policies/managed/managed_policies.json
            chmod 644 /etc/opt/chrome/policies/managed/managed_policies.json
        fi
        ;;
    chromium-browser)
        dnf install -y epel-release --setopt=install_weak_deps=false
        dnf install -y chromium --setopt=install_weak_deps=false
        ;;
    brave-browser)
        dnf install -y dnf-plugins-core --setopt=install_weak_deps=false
        dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
        dnf install -y brave-browser --setopt=install_weak_deps=false
        ;;
esac

# Create the directory for the systemd service override
mkdir -p /etc/systemd/system/getty@tty1.service.d/

# Create the override.conf file
cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<EOL
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin kiosk --noclear %I \$TERM
EOL

# Create the .kioskstartx file
cat > /home/kiosk/.kioskstartx <<EOL
#!/bin/bash
clear
sleep 5
$STARTXCMD
EOL

# Make .xinitrc owned by the kiosk user and executable
chown kiosk:kiosk /home/kiosk/.kioskstartx
chmod +x /home/kiosk/.kioskstartx

# Add ".kioskstartx file to bashrc (if not already)
grep -qxF "source /home/kiosk/.kioskstartx" /home/kiosk/.bashrc || echo "source /home/kiosk/.kioskstartx" >> /home/kiosk/.bashrc

# Create the .xinitrc file for the kiosk user
cat > /home/kiosk/.xinitrc <<EOL
#!/bin/bash

sleep 3

xrandr --output \$(xrandr | grep " connected " | awk '{ print\$1 }' | head -n 1) --mode $SCREEN_RESOLUTION$SCREEN_TEARING

xset s off
xset -dpms
xset s noblank

sleep 2

amixer -c $CARD sset Master 100%

SCREEN_RESOLUTION=\$(xrandr | grep '*' | awk '{print \$1}')

WIDTH=\$(echo \$SCREEN_RESOLUTION | cut -d 'x' -f 1)
HEIGHT=\$(echo \$SCREEN_RESOLUTION | cut -d 'x' -f 2)

$BROWSER$BROWSER_FLAGS --window-position=0,0 --window-size=\$WIDTH,\$HEIGHT$URL

while pgrep -x "$BROWSER" > /dev/null; do
    sleep 10
done

sudo systemctl reboot
EOL

# Make .xinitrc owned by the kiosk user and executable
chown kiosk:kiosk /home/kiosk/.xinitrc
chmod +x /home/kiosk/.xinitrc

# Make /etc/sudoers.d/reboot to grant Kiosk user reboot permissions
cat > /etc/sudoers.d/reboot <<EOL
kiosk ALL=NOPASSWD: /bin/systemctl reboot
EOL

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

if [ -z "$AUTOREBOOT" ]; then
    # Disable reboot task
    systemctl disable kiosk-auto-reboot.timer
else
  # Enable reboot task
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
ExecStart=/bin/bash -c "dnf upgrade -y"
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

if [ -z "$AUTOUPDATE" ]; then
    # Disable update task
    systemctl disable kiosk-auto-update.timer
else
  # Enable update task
    systemctl enable kiosk-auto-update.timer
fi

# Block all inbound connections
firewall-cmd --set-default-zone=drop
if [ -n "$SSH" ]; then
    firewall-cmd --zone=drop --add-service=ssh
fi
firewall-cmd --runtime-to-permanent

# Update GRUB configuration
sed -i 's/^GRUB_TIMEOUT=[0-9]*$/GRUB_TIMEOUT=0/' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg

# Reboot system
reboot
