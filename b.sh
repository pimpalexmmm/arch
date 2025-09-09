pacstrap -K /mnt base linux linux-firmware networkmanager vim
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
