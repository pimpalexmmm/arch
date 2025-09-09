#!/usr/bin/env bash
set -euo pipefail

# ===== تنظیمات پایه =====
HOSTNAME="arch-test"
USERNAME="amir"
USER_PASSWORD="test123"
LOCALE="en_US.UTF-8"
KEYMAP="us"
TIMEZONE="Asia/Tehran"
SWAP_SIZE_GB="8"

BASE_PKGS="base linux linux-firmware networkmanager sudo vim bash-completion git reflector curl xdg-user-dirs"
WAYLAND_PKGS="hyprland waybar wofi xdg-desktop-portal xdg-desktop-portal-hyprland pipewire wireplumber pipewire-pulse wl-clipboard grim slurp swww foot"
FONTS_PKGS="ttf-jetbrains-mono ttf-nerd-fonts-symbols noto-fonts noto-fonts-cjk noto-fonts-emoji papirus-icon-theme upower"

MIRROR_COUNTRIES="Germany,Netherlands,France,Finland,Switzerland,Austria"

# ===== بررسی UEFI و اینترنت =====
[[ -d /sys/firmware/efi ]] || { echo "[-] سیستم در حالت UEFI بوت نشده."; exit 1; }
ping -c 1 archlinux.org >/dev/null 2>&1 || { echo "[-] اینترنت در دسترس نیست."; exit 1; }

# ===== بهینه‌سازی mirror =====
pacman -Sy --noconfirm reflector
reflector --country "$MIRROR_COUNTRIES" --protocol https --age 12 --sort rate --save /etc/pacman.d/mirrorlist || true

# ===== پارتیشن‌بندی خودکار =====
DISK="/dev/sda"
sgdisk --zap-all "$DISK"
sgdisk -n 1:0:0 -t 1:8300 "$DISK"
mkfs.ext4 -F "${DISK}1"

# ===== مانت =====
mount "${DISK}1" /mnt

# ===== نصب پایه =====
pacstrap -K /mnt $BASE_PKGS $FONTS_PKGS

# ===== fstab =====
genfstab -U /mnt >> /mnt/etc/fstab

# ===== chroot =====
arch-chroot /mnt bash -eux <<'CHROOT_EOF'
HOSTNAME="'$HOSTNAME'"
USERNAME="'$USERNAME'"
USER_PASSWORD="'$USER_PASSWORD'"
LOCALE="'$LOCALE'"
KEYMAP="'$KEYMAP'"
TIMEZONE="'$TIMEZONE'"
WAYLAND_PKGS="'$WAYLAND_PKGS'"
FONTS_PKGS="'$FONTS_PKGS'"
SWAP_SIZE_GB="'$SWAP_SIZE_GB'"
MIRROR_COUNTRIES="'$MIRROR_COUNTRIES'"

# منطقه زمانی و locale
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc
sed -i "s/^#\(${LOCALE}\)/\1/" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf

# hostname و hosts
echo ${HOSTNAME} > /etc/hostname
cat >/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

# فعال‌سازی NetworkManager
systemctl enable NetworkManager

# کاربر و sudo
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
useradd -m -G wheel,video,audio,input ${USERNAME}
echo "${USERNAME}:${USER_PASSWORD}" | chpasswd
echo "root:${USER_PASSWORD}" | chpasswd
su - ${USERNAME} -c 'xdg-user-dirs-update'

# swapfile
fallocate -l "${SWAP_SIZE_GB}G" /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile none swap defaults 0 0" >> /etc/fstab
echo "vm.swappiness=10" > /etc/sysctl.d/99-swappiness.conf

# نصب Hyprland و ابزارها
pacman -S --noconfirm ${WAYLAND_PKGS}
pacman -S --noconfirm ${FONTS_PKGS}

# کانفیگ Hyprland
su - ${USERNAME} -c '
mkdir -p ~/.config/hypr ~/.config/waybar ~/.config/wofi ~/.config/wallpapers

# hyprland.conf
cat >~/.config/hypr/hyprland.conf <<EOF2
monitor=,preferred,auto,auto
exec-once=pipewire &
exec-once=wireplumber &
exec-once=swww init && swww img ~/.config/wallpapers/wall.jpg
exec-once=waybar &
\$mod = SUPER
bind = \$mod, RETURN, exec, foot
bind = \$mod, D, exec, wofi --show drun
general {
  gaps_in=6
  gaps_out=12
  border_size=2
  col.active_border=0xff5e81ac
  col.inactive_border=0xff3b4252
}
animations {
  enabled=1
  animation=windows,1,7,default
}
decoration {
  rounding=8
  blur=1
  blur_size=3
  blur_passes=2
}
EOF2

# waybar config
cat >~/.config/waybar/config.jsonc <<EOF3
{
  "layer": "top",
  "position": "top",
  "modules-left": ["clock"],
  "modules-right": ["cpu", "memory", "battery", "pulseaudio", "network"],
  "clock": { "format": "%a %d %b %H:%M" }
}
EOF3

# wofi style
cat >~/.config/wofi/style.css <<EOF4
window { background-color: rgba(25, 27, 38, 0.92); border-radius: 12px; }
EOF4

# والپیپر
curl -L -o ~/.config/wallpapers/wall.jpg https://w.wallhaven.cc/full/4g/wallhaven-4g8x3l.jpg || true
'
CHROOT_EOF

echo "[✓] نصب تست سریع کامل شد."
echo "umount -R /mnt && reboot"
echo "بعد از بوت، با کاربر ${USERNAME} وارد شو و دستور Hyprland رو بزن."