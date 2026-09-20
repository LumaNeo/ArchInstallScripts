#!/bin/bash
set -e

echo "=== Arch Linux Installation Configuration ==="

read -rp "Enter target disk [/dev/sda]: " INPUT_DISK </dev/tty
DISK="${INPUT_DISK:-/dev/sda}"

read -rp "Enter keymap [de-latin1]: " INPUT_KEYMAP </dev/tty
KEYMAP="${INPUT_KEYMAP:-de-latin1}"

read -rp "Enter timezone [Europe/Berlin]: " INPUT_TIMEZONE </dev/tty
TIMEZONE="${INPUT_TIMEZONE:-Europe/Berlin}"

read -rp "Enter format locale [de_DE]: " INPUT_FORMAT_LOCALE </dev/tty
FORMAT_LOCALE="${INPUT_FORMAT_LOCALE:-de_DE}"

read -rp "Enter display language locale [en_US]: " INPUT_DISPLAY_LANG_LOCALE </dev/tty
DISPLAY_LANG_LOCALE="${INPUT_DISPLAY_LANG_LOCALE:-en_US}"

read -rp "Enter hostname [neo]: " INPUT_HOSTNAME </dev/tty
HOSTNAME="${INPUT_HOSTNAME:-neo}"

read -rp "Enter username [luma]: " INPUT_USERNAME </dev/tty
USERNAME="${INPUT_USERNAME:-luma}"

read -rsp "Enter user password: " USER_PASSWORD </dev/tty
echo ""
read -rsp "Enter root password: " ROOT_PASSWORD </dev/tty
echo ""

read -rp "Enter swap size [4GiB]: " INPUT_SWAP_SIZE </dev/tty
SWAP_SIZE="${INPUT_SWAP_SIZE:-4GiB}"

echo -e "\n=== Configuration Summary ==="
echo "Disk:           $DISK"
echo "Keymap:         $KEYMAP"
echo "Timezone:       $TIMEZONE"
echo "Locales:        $FORMAT_LOCALE / $DISPLAY_LANG_LOCALE"
echo "Hostname:       $HOSTNAME"
echo "User:           $USERNAME"
echo "Swap Size:      $SWAP_SIZE"
echo "============================="
read -rp "Proceed with installation? (y/N): " CONFIRM </dev/tty
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 1
fi

echo "=== Setting Keymap ==="
loadkeys "$KEYMAP"

echo "=== Partitioning Disk ($DISK) ==="
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart primary fat32 1MiB 100MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary linux-swap 100MiB "$SWAP_SIZE"
parted -s "$DISK" mkpart primary ext4 "$SWAP_SIZE" 100%

if [[ "$DISK" =~ "nvme" ]]; then
    BOOT_PART="${DISK}p1"
    SWAP_PART="${DISK}p2"
    ROOT_PART="${DISK}p3"
else
    BOOT_PART="${DISK}1"
    SWAP_PART="${DISK}2"
    ROOT_PART="${DISK}3"
fi

echo "=== Formatting Partitions ==="
mkfs.ext4 -F "$ROOT_PART"
mkfs.fat -F 32 "$BOOT_PART"
mkswap "$SWAP_PART"

echo "=== Mounting Partitions ==="
mount "$ROOT_PART" /mnt
mount --mkdir "$BOOT_PART" /mnt/boot/efi
swapon "$SWAP_PART"

echo "=== Installing Base System (Pacstrap) ==="
pacstrap -K /mnt \
    base \
    linux \
    linux-firmware \
    sof-firmware \
    base-devel \
    grub \
    efibootmgr \
    nano \
    networkmanager \
    iwd \
    dhcpcd

echo "=== Generating Fstab ==="
genfstab -U /mnt >> /mnt/etc/fstab

echo "=== Entering Chroot Environment ==="
arch-chroot /mnt /bin/bash <<EOF
set -e

echo "--> Setting Timezone"
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

echo "--> Configuring Locales"
echo "$FORMAT_LOCALE.UTF-8 UTF-8" >> /etc/locale.gen
echo "$DISPLAY_LANG_LOCALE.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

cat <<LOCALECONF > /etc/locale.conf
LANG=$FORMAT_LOCALE.UTF-8
LC_MESSAGES=$DISPLAY_LANG_LOCALE.UTF-8
LOCALECONF

echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

echo "--> Setting Hostname"
echo "$HOSTNAME" > /etc/hostname

echo "--> Configuring Passwords and Users"
echo "root:$ROOT_PASSWORD" | chpasswd

useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "$USERNAME:$USER_PASSWORD" | chpasswd

echo "--> Granting Sudo Privileges"
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "--> Enabling Services"
systemctl enable NetworkManager iwd dhcpcd

echo "--> Installing GRUB Bootloader"
grub-install "$DISK"
grub-mkconfig -o /boot/grub/grub.cfg
EOF

echo "=== Unmounting Drives ==="
umount -R /mnt

echo "=== Base Installation Complete ==="
