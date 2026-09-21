#!/bin/bash
set -e

clear

SCRIPT_PATH="$(readlink -f "$0")"

echo "=== Arch Linux Post-Installation Configuration ==="

read -rp "Enter Window Manager [hyprland]: " WINDOW_MANAGER </dev/tty
WINDOW_MANAGER="${WINDOW_MANAGER:-hyprland}"

read -rp "Enter Terminal [kitty]: " TERMINAL </dev/tty
TERMINAL="${TERMINAL:-kitty}"

read -rp "Enter File Manager [thunar]: " FILE_MANAGER </dev/tty
FILE_MANAGER="${FILE_MANAGER:-thunar}"

read -rp "Enter Browser [librewolf]: " BROWSER </dev/tty
BROWSER="${BROWSER:-librewolf}"

echo -e "\n=== Configuration Summary ==="
echo "Window Manager: $WINDOW_MANAGER"
echo "Terminal:       $TERMINAL"
echo "File Manager:   $FILE_MANAGER"
echo "Browser:        $BROWSER"
echo "============================="

echo ""
read -rp "Proceed with installation? (y/Y): " CONFIRM </dev/tty
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 1
fi

echo "=== Updating System ==="
sudo pacman -Syu --noconfirm

echo "=== Installing Official Arch Packages ==="
sudo pacman -S --needed --noconfirm \
    $WINDOW_MANAGER \
    $TERMINAL \
    $FILE_MANAGER \
    $BROWSER \
    sddm \
    git

echo "=== Installing AUR Helper (yay) ==="
git clone https://aur.archlinux.org/yay.git
(cd yay && makepkg -si --noconfirm)
rm -rf yay

echo "=== Installing Nix Package Manager (Multi-User Installer) ==="
mkdir -p /tmp
curl -sSL -o /tmp/install.sh https://nixos.org/nix/install
sh /tmp/install.sh --daemon --yes </dev/null
rm -rf /tmp
if systemctl list-unit-files | grep -q "nix-daemon.service"; then
    sudo systemctl enable --now nix-daemon.service
fi

sudo mkdir -p /etc/nix
echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf > /dev/null

echo "=== Enabling Display Manager ==="
sudo systemctl enable sddm

echo "=== Post-Installation Complete ==="

rm -f "$SCRIPT_PATH"

echo ""
read -rp "Reboot system now? (y/Y): " REBOOT_CONFIRM </dev/tty
REBOOT_CONFIRM="${REBOOT_CONFIRM:-Y}"

if [[ "$REBOOT_CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Rebooting..."
    sudo reboot
else
    echo "Reboot skipped"
fi
