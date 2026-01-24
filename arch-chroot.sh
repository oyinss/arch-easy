#!/bin/bash
set -e

# -------------------------------------
# Define partitions
# -------------------------------------
EFI=/dev/nvme0n1p1
ROOT=/dev/nvme0n1p3

# -------------------------------------
# Mount all BTRFS subvolumes for chroot
# -------------------------------------
echo "[*] Mounting root subvolumes..."

mount -o noatime,compress=zstd,subvol=@ "$ROOT" /mnt
mkdir -p /mnt/{boot/efi,home,var/log,var/cache,.snapshots}

mount -o noatime,compress=zstd,subvol=@home       "$ROOT" /mnt/home
mount -o noatime,compress=zstd,subvol=@log        "$ROOT" /mnt/var/log
mount -o noatime,compress=zstd,subvol=@cache      "$ROOT" /mnt/var/cache
mount -o noatime,compress=zstd,subvol=@snapshots  "$ROOT" /mnt/.snapshots

# -------------------------------------
# Mount EFI
# -------------------------------------
echo "[*] Mounting EFI partition..."
mount "$EFI" /mnt/boot/efi

# -------------------------------------
# Enter chroot
# -------------------------------------
echo "[+] All subvolumes mounted. Entering chroot..."
arch-chroot /mnt