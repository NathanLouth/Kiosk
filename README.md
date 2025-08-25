# Kiosk System Setup Script

## Overview
This script configures a Linux system to run as a kiosk. It sets up an automatic login for the kiosk user, starts Sway (Wayland Kiosk Compositor), and launches a browser that can run in kiosk mode and display a predefined web page. The system also disables the GRUB boot menu.

## Prerequisites
- A fresh installation of `Debian 13` (Minimal no GUI install).
- A user account named `kiosk` (ensure this user exists before running the script).
- `root privileges` to run administrative commands (Root enabled).

## How to Use the Script

> [!NOTE]
> You must be logged in as the root user.

### Step 1: Install wget

Ensure that wget is installed, as it is required to download the script:

```bash
apt install -y wget
```

### Step 2: Download the Script

Download the kiosk setup script using wget:

```bash
wget https://raw.githubusercontent.com/NathanLouth/Kiosk/refs/heads/main/install.sh
```

### Step 3: Make the Script Executable

Change the script's permissions to make it executable:

```bash
chmod +x install.sh
```

### Step 4: Run the Script

Execute the script with sudo to start the kiosk setup process:

```bash
./install.sh
```

The script will complete the setup, automatically logging in as the kiosk user, starting Sway (Wayland Kiosk Compositor), and launching the selected browser in kiosk mode. Once the script finishes, the system will reboot.

## Command-Line Arguments

> [!NOTE]
> It is recommended that you explicitly use the arguments, as the default values may change in future releases.

The script supports the following optional command-line arguments for customizing the kiosk setup:

    --card X
        Set the audio card number. The value of X should be a number. (Default is 0)

    --device X
        Set the audio device number. The value of X should be a number. (Default is 0)

    --browser X
        Specify which browser to use. Valid options are:
            chrome (Google Chrome)
            chromium (Default)
            brave (Brave Browser)
    
    --screen X
        Set the screen resolution e.g 1920x1080 (Default is 1920x1080)

    --auto-reboot X
        Enable auto reboot X should be a number in minutes (60 reboot every hour) (Default is disabled)
            
    --url X
        Specify the URL to display in kiosk mode. Encloses the URL in quotes. (Default New Tab Page)

    --auto-refresh X
        Enable auto refresh X should be a number in seconds (300 refresh every 5 minutes) (Default is disabled)

    --auto-update
        Update system weekly

    --incognito
        launch browser using incognito mode
        
    --kiosk
        launch browser in kiosk mode (hides url bar)

    --block-downloads
        Blocks downloading files through the browser

    --ad-block
        Installs uBlock Origin Lite on Chrome or Chromium

    --hide-cursor
        Hides the mouse cursor after 3 seconds of inactivity
        
## Example Usage

Default setup:

```bash
./install.sh
```

Set custom audio card and device:

```bash
./install.sh --card 1 --device 0
```

Choose Chrome as the browser:

```bash
./install.sh --browser chrome
```

Set both a custom audio card and browser to Chromium:

```bash
./install.sh --card 1 --device 0 --browser chromium
```

Set specific screen resolution:

```bash
./install.sh --screen 3840x2160
```

Launch Chrome in kiosk mode with incognito and custom URL:

```bash
./install.sh --browser chrome --kiosk --incognito --url "https://example.org"
```

## Troubleshooting

### Initializing Graphics Drivers or Establishing Network Connection

The system waits for both the graphics driver to fully initialize and for the machine to connect to the network before starting Sway. If Sway isn't launching, it's likely that one or both of these conditions haven't been met.

If you prefer, you can disable this behavior by editing the file `/home/kiosk/.startkiosk`

###### Checking Network Connectivity:
To verify if your system is connected to the network, run the following command:
```bash
`ping <IP ADDRESS OR WEBSITE DOMAIN>`
```
You should see a response if the system is connected. If no response is received, the system is not connected to the network.

###### Checking Graphics Driver Initialization:
To check if the graphics driver has initialized correctly, run the following command:
```bash
`ls /dev/dri | grep "card"`
```
If the output includes `cardX`, it means the graphics driver has been initialized. If there's no output, the graphics driver has not been initialized.

### Sway (Wayland Kiosk Compositor) Error
If Sway (Wayland Kiosk Compositor) fails to launch, try running the script again. This will reinstall the necessary packages.

### The Browser Not Launching
If the selected browser does not launch, ensure that the kiosk user has the appropriate permissions and that Sway and the browser are properly installed.

### Screen Resolution Issues
If the screen resolution is not correct after using the --screen argument, check and modify the resolution settings in the Sway config file (/home/kiosk/.config/sway/config).

### Autologin Not Working
Verify that the getty@tty1.service.d/override.conf file is created correctly and that the kiosk user is configured to log in automatically.

### Audio Problems
If audio isn't working:

1. Get audio device(s) info:
   ```bash
   aplay -l
   ```
2. Verify ALSA configuration in `/etc/asound.conf` edit card and device numbers as needed.
   
3. Check volume levels:
   ```bash
   amixer -c 0 sset Master unmute
   ```
   
## License
MIT License

This script is provided as-is and can be freely used and modified. No warranty or guarantee is provided.
