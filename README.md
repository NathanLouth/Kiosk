# Kiosk System Setup Script

## Overview
This script configures a Linux system to run as a kiosk. It sets up an automatic login for the kiosk user, starts the X server, and launches Chromium in kiosk mode to display a predefined web page. The system also disables the GRUB boot menu and boots directly into the kiosk interface.

## Prerequisites
- A fresh installation of `Alma Linux 9.x` (Minimal Install or Custom Operating System).
- A user account named `kiosk` (ensure this user exists before running the script).
- `root privileges` to run administrative commands (Root enabled).

## How to Use the Script

> [!NOTE]
> You must be logged in as the root user.

### Step 1: Install wget

Ensure that wget is installed, as it is required to download the script:

```bash
dnf install -y wget
```

### Step 2: Download the Script

Download the kiosk setup script using wget:

```bash
wget https://raw.githubusercontent.com/NathanLouth/Kiosk/refs/heads/Release/install.sh
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

The script will complete the setup, automatically logging in as the kiosk user, starting the X server, and launching Chromium in kiosk mode. Once the script finishes, the system will reboot. After the reboot, the kiosk interface will start automatically.

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

    --auto-update
        Update system weekly

    --incognito
        launch browser using incognito mode
        
    --kiosk
        launch browser in kiosk mode (hides url bar)

    --no-cursor
        Hides the mouse cursor 

    --no-tearfree
        Disable TearFree (Use when running as a virtual machine under KVM)

    --block-downloads
        Blocks downloading files through the browser

    --keep-ssh
        Stop OpenSSH from being disabled and uninstalled as part of the install
        
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

Disable TearFree:

```bash
./install.sh --browser chrome --no-tearfree --kiosk --screen 1920x1080
```

Hidden cursor:

```bash
./install.sh --no-cursor
```

## Troubleshooting

### Startx Error
If startx fails to launch, try running the script again. This will reinstall the necessary packages.

### Chromium Not Launching
If Chromium does not launch, ensure that the kiosk user has the appropriate permissions and that xinit and Chromium are properly installed.

### Screen Resolution Issues
If the screen resolution does not appear correctly, modify the xrandr settings in the .xinitrc file (/home/kiosk/.xinitrc).
If the screen resolution is incorrect, some GPU drivers do not support the TearFree option, try rerunning the script with the `--no-tearfree` argument. Please note that disabling this option may lead to screen tearing. (Use `--no-tearfree` when running in a virtual machine under KVM.)

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
