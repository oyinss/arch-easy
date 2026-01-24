#!/bin/bash
set -e

# -------------------------------------
# Prompt for user credentials (with visible verification)
# -------------------------------------
read -rp "Enter new username: " username

# User password
while true; do
  read -rp "Enter password for $username (visible): " userpass
  read -rp "Confirm password for $username: " userpass2
  [[ "$userpass" == "$userpass2" ]] && break
  echo "[!] Passwords do not match. Try again."
done

# Root password
while true; do
  read -rp "Enter password for root (visible): " rootpass
  read -rp "Confirm password for root: " rootpass2
  [[ "$rootpass" == "$rootpass2" ]] && break
  echo "[!] Passwords do not match. Try again."
done

# -------------------------------------
# Define partitions
# -------------------------------------
EFI=/dev/nvme0n1p1
SWAP=/dev/nvme0n1p2
ROOT=/dev/nvme0n1p3

# -------------------------------------
# Format and prepare disk
# -------------------------------------
mkfs.fat -F32 $EFI
mkswap $SWAP
swapon $SWAP
mkfs.btrfs -f $ROOT

mount $ROOT /mnt
btrfs su cr /mnt/@
btrfs su cr /mnt/@home
btrfs su cr /mnt/@log
btrfs su cr /mnt/@cache
btrfs su cr /mnt/@snapshots
umount /mnt

# -------------------------------------
# Mount BTRFS subvolumes
# -------------------------------------
mount -o noatime,compress=zstd,subvol=@ $ROOT /mnt
mkdir -p /mnt/{boot/efi,home,var/log,var/cache,.snapshots}
mount -o noatime,compress=zstd,subvol=@home $ROOT /mnt/home
mount -o noatime,compress=zstd,subvol=@log $ROOT /mnt/var/log
mount -o noatime,compress=zstd,subvol=@cache $ROOT /mnt/var/cache
mount -o noatime,compress=zstd,subvol=@snapshots $ROOT /mnt/.snapshots
mount $EFI /mnt/boot/efi

# -------------------------------------
# Define essential packages
# -------------------------------------
essentialPkgs=(
  # === BASE SYSTEM ===
  base
  base-devel
  linux
  linux-headers
  linux-firmware
  intel-ucode
  sudo
  gnupg

  # === SHELL / EDITORS ===
  nano
  neovim
  zsh

  # === DEV TOOLS ===
  git

  # === BOOTLOADER ===
  grub
  efibootmgr
  grub-btrfs
  timeshift
  os-prober

  # === NETWORK & BLUETOOTH ===
  networkmanager
  plasma-nm
  bluez
  bluez-utils
  bluedevil

  # === DISPLAY SERVER ===
  xorg
  xdg-utils
  xdg-user-dirs

  # === PLASMA DESKTOP ===
  plasma-desktop
  sddm
  konsole
  dolphin
  kdeconnect

  # === SYSTEM SERVICES ===
  firewalld
  upower
  openssh
)

# -------------------------------------
# Install base system
# -------------------------------------
until pacstrap /mnt "${essentialPkgs[@]}"; do
  echo "[!] pacstrap failed. Retrying in 5s..."
  sleep 5
done

# -------------------------------------
# Generate fstab
# -------------------------------------
genfstab -U /mnt >> /mnt/etc/fstab

# -------------------------------------
# Get UUIDs
# -------------------------------------
ROOT_UUID=$(blkid -s UUID -o value $ROOT)
SWAP_UUID=$(blkid -s UUID -o value $SWAP)

# -------------------------------------
# Chroot and configure system
# -------------------------------------
arch-chroot /mnt /bin/bash <<EOF
set -e

# Timezone and locales
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us-intl" > /etc/vconsole.conf

# Hostname
echo "ArchLinux" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1 localhost
::1       localhost
127.0.1.1 ArchLinux.localdomain ArchLinux
HOSTS

# Initramfs
sed -i 's/^HOOKS=(.*/HOOKS=(base udev autodetect modconf block filesystems keyboard resume fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# GRUB
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# User + sudo
useradd -m -G wheel,power,storage -s /bin/zsh "$username"
echo "$username:$userpass" | chpasswd
echo "root:$rootpass" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# NetworkManager config
cat > /etc/NetworkManager/NetworkManager.conf <<NMCONFIG
[main]
plugins=keyfile

[ifupdown]
managed=true

[device]
wifi.scan-rand-mac-address=no
NMCONFIG

# Enable services
systemctl enable sddm
systemctl enable bluetooth
systemctl enable firewalld
systemctl enable NetworkManager
systemctl enable upower.service
systemctl enable sshd
systemctl enable avahi-daemon
systemctl enable fstrim.timer
systemctl enable systemd-hibernate.service

# Set time
sudo timedatectl set-timezone Africa/Lagos

# Turn off WatchDog at reboot
echo "RebootWatchdogSec=0" | sudo tee --append /etc/systemd/system.conf
EOF

# -------------------------------------
# Reboot prompt
# -------------------------------------
echo
read -rp "System installation complete. Reboot now? [y/N]: " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
  umount -R /mnt
  reboot
else
  echo "You can chroot manually later with: arch-chroot /mnt"
fi
