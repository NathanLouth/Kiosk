# Kiosk System Setup Script

## Overview
This script configures a Linux system to run as a kiosk. It sets up an automatic login for the kiosk user, starts the X server, and launches Chromium in kiosk mode to display a predefined web page. The system also disables the GRUB boot menu and boots directly into the kiosk interface.

## Prerequisites
- A fresh installation of `Alma Linux` (Minimal Install or Custom Operating System).
- A user account named kiosk (ensure this user exists before running the script).
- root privileges to run administrative commands (Root enabled).

1. **Update the System:**
   The script run `dnf update -y` to update the system.

2. **Install Necessary Packages:**
   It installs the following essential packages:
   - `Hardware Support`: Installs hardware drivers
   - `base-x`: Installs Xorg Window System
   - `alsa-utils`: Install tools for adjusting audio settings
   - `google-chrome-stable` or `chromium`: Installs web browser

3. **Create Systemd Service Override for Getty Service:**
   The script creates a custom systemd service configuration to enable automatic login for the kiosk user at the first terminal (tty1).

4. **Configure Autologin for the kiosk User:**
   It modifies the systemd service configuration to allow the kiosk user to log in automatically without a password.

5. **Configure X11 to Start Chromium in Kiosk Mode:**
   The script adds the startx command to the .bashrc file of the kiosk user, ensuring the X server starts upon login. It also creates a custom .xinitrc file to configure:
   - Screen resolution
   - Launch Chromium in full-screen kiosk mode
   - Set system volume to maximum using amixer
   - adds "sleep 5" before startx (fixes xorg crashing)

6. **Display Settings Configuration**
   - Disables screen saver and blanking with `xset s off` and `xset s noblank`
   - Prevents DPMS (Energy Star) features with `xset -dpms`
   - These settings ensure continuous operation without display interruptions

7. **Audio Configuration**
   - Creates `/etc/asound.conf` for consistent audio device setup
   - Ensures reliable audio functionality across reboots

8. **Fixes Screen Tearing**
   Sets Xorg option TearFree

9. **Update the GRUB Configuration:**
    It disables the GRUB boot menu timeout by setting GRUB_TIMEOUT=0, ensuring the system boots directly to the kiosk interface.

10. **Update GRUB:**
    The script runs update-grub to apply the new GRUB settings.

11. **Reboot the System:**
    The system is rebooted automatically, and upon restart, the kiosk setup will be active.

## How to Use the Script

### Note: You must be logged in as the root user

### Step 1: Install wget

Ensure that wget is installed, as it is required to download the script:

```bash
dnf install -y wget
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

The script will complete the setup, automatically logging in as the kiosk user, starting the X server, and launching Chromium in kiosk mode. Once the script finishes, the system will reboot. After the reboot, the kiosk interface will start automatically.

## Command-Line Arguments

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
        Disable TearFree

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
   
## Additional Customizations

### Note: To drop to a terminal session press `Ctrl+Alt+F2`

* To change the web page Chromium displays, modify the URL in the .xinitrc file (/home/kiosk/.xinitrc). By default the page is set to `New Tab Page`

* To make Chromium open using incognito mode or show the url bar you can edit the following chromium flags in the .xinitrc file (/home/kiosk/.xinitrc):
  `--kiosk`
  `--incognito`
  
* Adjust the screen resolution or other display settings by modifying the xrandr command in the .xinitrc file (/home/kiosk/.xinitrc).
  
* To customize the behavior of autologin, you can modify the systemd service configuration at /etc/systemd/system/getty@tty1.service.d/override.conf.
  
* To set what audio output to use edit `/etc/asound.conf` you can find audio information running the command `aplay -l`
  
* To adjust the system volume, modify the amixer command in the .xinitrc file. The current setting uses card 0 (first sound card) and sets the master channel to 100%.

```bash
amixer -c 0 sset Master 100%
```

* To hide the mouse edit `/home/kiosk/.bashrc` change `startx` to `startx -- -nocursor`

## License
MIT License

This script is provided as-is and can be freely used and modified. No warranty or guarantee is provided.
