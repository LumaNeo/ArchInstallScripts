#!/bin/bash
set -e

# Store the script's path for clean self-deletion
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

echo -e "\n===== Configuration Summary ====="
echo "Window Manager:  $WINDOW_MANAGER"
echo "Terminal:        $TERMINAL"
echo "File Manager:    $FILE_MANAGER"
echo "Browser:         $BROWSER"
echo "================================"

echo ""
read -rp "Proceed with installation? (y/N): " CONFIRM </dev/tty
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
    git \
    qt5-wayland \
    qt6-wayland

echo "=== Installing AUR Helper (yay) ==="
TEMP_DIR=$(mktemp -d)
git clone https://aur.archlinux.org/yay.git "$TEMP_DIR/yay"
(cd "$TEMP_DIR/yay" && makepkg -si --noconfirm)
rm -rf "$TEMP_DIR"

echo "=== Installing Nix Package Manager (Multi-User Installer) ==="
curl --proto '=https' --tlsv1.2 -sSf https://nixos.org/nix/install | sh -s -- --daemon --yes

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
