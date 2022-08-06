#!/bin/bash

save_config() {
  # DISK
  fdisk -l
  echo -e "\nWELCOME!\n"
  while read -rp "Enter the target disk (e.g. /dev/sda): " DISK; do
    if [ -b "$DISK" ]; then
      break
    else
      echo "Invalid disk $DISK"
    fi
  done

  # MY_USERNAME
  read -rp "Enter the username: " MY_USERNAME

  # PASSWORD
  read -rsp "Enter the password for $MY_USERNAME: " PASSWORD
  echo
  read -rsp "Re-enter the password for $MY_USERNAME: " PASSWORD_CHECK
  echo
  while [[ "$PASSWORD" != "$PASSWORD_CHECK" ]]; do
    read -rsp "Sorry, passwords do not match. Enter the password for $MY_USERNAME: " PASSWORD
    echo
    read -rsp "Re-enter the password for $MY_USERNAME: " PASSWORD_CHECK
    echo
  done

  # MY_HOSTNAME
  read -rp "Enter the hostname: " MY_HOSTNAME

  # LUKS_PASSPHRASE
  read -rsp "Enter the LUKS passphrase for ${DISK}3: " LUKS_PASSPHRASE
  echo
  read -rsp "Re-enter the LUKS passphrase for ${DISK}3: " LUKS_PASSPHRASE_CHECK
  echo
  while [[ "$LUKS_PASSPHRASE" != "$LUKS_PASSPHRASE_CHECK" ]]; do
    read -rsp "Sorry, passphrase do not match. Enter the LUKS passphrase for ${DISK}3: " LUKS_PASSPHRASE
    echo
    read -rsp "Re-enter the LUKS passphrase for ${DISK}3: " LUKS_PASSPHRASE_CHECK
    echo
  done
  unset LUKS_PASSPHRASE_CHECK

  # Install dotfiles?
  # DOTFILES_NEEDED to lowercase
  while [[ ! "$DOTFILES_NEEDED" =~ ^y|n$ ]]; do
    read -rp "Do you want to install your dotfiles? (y|n): " DOTFILES_NEEDED
  done
  echo

  {
    echo DISK="$DISK"
    echo MY_USERNAME="$MY_USERNAME"
    echo PASSWORD="$PASSWORD"
    echo MY_HOSTNAME="$MY_HOSTNAME"
    echo DOTFILES_NEEDED="$DOTFILES_NEEDED"
  } >"$STARTDIR/cfg"
}

partition_disk() {
  echo -e "\nZAPPING & PARTITIONING DISK..." && sleep 3
  sgdisk -Z "$DISK"                                                 # zap GPT & MBR
  sgdisk -og "$DISK"                                                # partition tables: create GPT with protective MBR
  sgdisk -n 1::+1M -t 1:ef02 -c 1:"BIOS Boot Partition" "$DISK"     # /dev/sda1. BIOS, For GPT with GRUB (Legacy)
  sgdisk -n 2::+550M -t 2:ef00 -c 2:"EFI System Partition" "$DISK"  # /dev/sda2. ESP, for UEFI
  sgdisk -n 3:: -c 3:"Linux filesystem" "$DISK"                     # /dev/sda3. CRYPTROOT
}

encrypt_root() {
  echo -e "\nENCRYPTING ROOT..." && sleep 3
  echo "$LUKS_PASSPHRASE" | cryptsetup -qv --type luks1 --cipher aes-xts-plain64 --key-size 512 --hash sha512 --iter-time 5000 --use-urandom \
    luksFormat "${DISK}3" # luks1 for GRUB compatibility
}

format_disk() {
  echo -e "\nFORMATTING DISK..." && sleep 3
  # ESP
  mkfs.vfat -F32 -n ESP "${DISK}2"
  # CRYPTROOT
  echo "$LUKS_PASSPHRASE" | cryptsetup luksOpen "${DISK}3" cryptroot
  mkfs.btrfs -L CRYPTROOT /dev/mapper/cryptroot
  unset LUKS_PASSPHRASE
}

btrfs_setup() {
  echo -e "\nSETTING UP BTRFS..." && sleep 3
  subvols=(
    "@"
    "@home"
    "@opt"
    "@var"
  )

  paths=(
    "/"
    "/home"
    "/opt"
    "/var"
  )
  # Mount root
  mount /dev/mapper/cryptroot /mnt

  pushd /mnt || exit 1
  for i in ${!subvols[*]}; do
    btrfs subvolume create "${subvols[$i]}"
  done
  popd || exit 1 # $STARTDIR

  # Unmount root
  umount /mnt

  # Remount root with subvolumes
  for i in ${!subvols[*]}; do
    mkdir -p "/mnt${paths[$i]}"
    mount -o noatime,nodiratime,space_cache=v2,compress=lzo:6,ssd,discard=async,subvol="${subvols[$i]}" \
      /dev/mapper/cryptroot "/mnt${paths[$i]}"
  done

  # mount ESP on /mnt/boot
  mkdir -p /mnt/boot
  mount "${DISK}2" /mnt/boot
}

pacstrap_base() {
  echo -e "\nINSTALLING BASE PACKAGES..." && sleep 3
  pacstrap /mnt --needed base base-devel linux linux-firmware linux-headers \
    intel-ucode btrfs-progs git nano
    # parted cryptsetup dhcpcd man-db man-pages
}

save_config
partition_disk
encrypt_root
format_disk
btrfs_setup
pacstrap_base

echo -e "\nGENERATING FSTAB..." && sleep 3
genfstab -U /mnt >>/mnt/etc/fstab

echo -e "\nCOPYING REPO..." && sleep 3
cp -R "$STARTDIR/" /mnt/
