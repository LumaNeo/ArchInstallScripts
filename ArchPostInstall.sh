#!/bin/bash
set -e

echo "=== Updating System ==="
sudo pacman -Syu --noconfirm

echo "=== Installing Official Arch Packages ==="
sudo pacman -S --needed --noconfirm \
    hyprland \
    sddm \
    kitty \
    thunar \
    librewolf \
    git

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