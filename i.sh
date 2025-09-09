# پاک کردن جدول پارتیشن و ساخت GPT
sgdisk --zap-all /dev/sda
parted -s /dev/sda mklabel gpt

# ساخت پارتیشن EFI (بوت) و روت
parted -s /dev/sda mkpart ESP fat32 1MiB 513MiB
parted -s /dev/sda set 1 esp on
parted -s /dev/sda mkpart ROOT ext4 513MiB 100%

# فرمت کردن
mkfs.fat -F32 /dev/sda1
mkfs.ext4 -F /dev/sda2

# مانت کردن
mount /dev/sda2 /mnt
mkdir -p /mnt/boot/efi
mount /dev/sda1 /mnt/boot/efi
