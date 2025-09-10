#!/bin/bash
set -e

echo "==> تنظیم منطقه زمانی و ساعت"
ln -sf /usr/share/zoneinfo/Asia/Tehran /etc/localtime
hwclock --systohc

echo "==> فعال‌کردن locale"
sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/; s/^#\(fa_IR.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo 'KEYMAP=us' > /etc/vconsole.conf

echo "==> تنظیم hostname و hosts"
echo "archbox" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   archbox.localdomain archbox
EOF

echo "==> ساخت کاربر و رمز"
echo "root:root" | chpasswd
useradd -m -G wheel amir
echo "amir:test123" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "==> نصب بوت‌لودر و مایکروکد اینتل"
pacman -S --noconfirm intel-ucode grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch
grub-mkconfig -o /boot/grub/grub.cfg

echo "==> فعال‌کردن شبکه"
systemctl enable NetworkManager

echo "==> نصب پکیج‌های گرافیکی و Hyprland"
pacman -S --needed --noconfirm \
mesa vulkan-intel intel-media-driver libva-utils \
pipewire wireplumber pipewire-alsa pipewire-pulse \
hyprland waybar wofi kitty \
xdg-desktop-portal-hyprland xdg-desktop-portal \
polkit-gnome \
wl-clipboard grim slurp swaybg brightnessctl playerctl \
ttf-dejavu ttf-liberation noto-fonts noto-fonts-cjk noto-fonts-emoji

echo "==> ساخت پوشه‌های کانفیگ"
mkdir -p /home/amir/.config/hypr /home/amir/.config/waybar /home/amir/.config/wofi
chown -R amir:amir /home/amir/.config

echo "==> کانفیگ Hyprland"
cat > /home/amir/.config/hypr/hyprland.conf <<'EOF'
monitor=,preferred,auto,auto

exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
exec-once = waybar &
exec-once = swaybg -i /usr/share/backgrounds/archlinux/archbtw.jpg -m fill &
exec-once = xdg-desktop-portal-hyprland &

input {
  kb_layout = us
  follow_mouse = 1
}

general {
  gaps_in = 8
  gaps_out = 16
  border_size = 2
  layout = dwindle
}

decoration {
  rounding = 8
  active_opacity = 1.0
  inactive_opacity = 0.95
}

bind = SUPER, Return, exec, kitty
bind = SUPER, Q, killactive,
bind = SUPER, E, exec, wofi --show drun
bind = SUPER, Space, togglefloating,
EOF
chown amir:amir /home/amir/.config/hypr/hyprland.conf

echo "==> کانفیگ Waybar"
cat > /home/amir/.config/waybar/config.jsonc <<'EOF'
{
  "layer": "top",
  "position": "top",
  "modules-left": ["hyprland/workspaces"],
  "modules-center": ["clock"],
  "modules-right": ["pulseaudio", "network", "cpu", "memory"],
  "clock": { "format": "{:%a %d %b | %H:%M}" }
}
EOF

cat > /home/amir/.config/waybar/style.css <<'EOF'
* {
  font-family: "Noto Sans", "DejaVu Sans", sans-serif;
  font-size: 12px;
  color: #ECEFF4;
}
window {
  background: rgba(25, 25, 25, 0.6);
}
#workspaces button.focused {
  background: #5E81AC;
  color: #ECEFF4;
  border-radius: 6px;
}
EOF
chown -R amir:amir /home/amir/.config/waybar

echo "==> کانفیگ Wofi"
cat > /home/amir/.config/wofi/style.css <<'EOF'
window {
  border-radius: 10px;
  background-color: rgba(30, 30, 30, 0.9);
}
#input {
  margin: 8px;
  padding: 8px;
  border-radius: 6px;
  background-color: rgba(50, 50, 50, 0.8);
  color: #ECEFF4;
}
#entry:selected {
  background: #5E81AC;
  color: #ECEFF4;
}
EOF
chown -R amir:amir /home/amir/.config/wofi

echo "==> دانلود والپیپر"
mkdir -p /usr/share/backgrounds/archlinux
curl -L -o /usr/share/backgrounds/archlinux/archbtw.jpg \
https://images.unsplash.com/photo-1503264116251-35a269479413?q=80&w=1920

echo "==> فعال‌کردن اجرای خودکار Hyprland در TTY1"
echo '[ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ] && exec Hyprland' >> /home/amir/.bash_profile
chown amir:amir /home/amir/.bash_profile

echo "✅ همه‌چیز آماده است. بعد از خروج از chroot و ریبوت، مستقیماً وارد Hyprland می‌شوی."
