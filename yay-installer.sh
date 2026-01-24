#!/bin/bash
set -e

# Set AUR directory
AUR_DIR="$HOME/AUR"
YAY_DIR="$AUR_DIR/yay"

# Prepare directory
mkdir -p "$AUR_DIR"
cd "$AUR_DIR"

# Clone yay if not already present
if [ ! -d "$YAY_DIR" ]; then
    git clone https://aur.archlinux.org/yay.git
else
    echo "yay already cloned at $YAY_DIR"
fi

# Build and install
cd "$YAY_DIR"
makepkg -si
