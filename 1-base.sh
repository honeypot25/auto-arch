#!/bin/bash

source auto-arch/cfg

pacman -S --needed --noconfirm archlinux-keyring
pacman -S --needed --noconfirm pacman-contrib
setfont ter-v16b

timezone_and_localization() {
  echo -e "\nSETTING TIMEZONE AND LOCALIZATION..." && sleep 3
  # timezone
  timedatectl set-timezone "Europe/Rome"
  ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime
  # locale
  sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
  sed -i 's/^#it_IT.UTF-8 UTF-8/it_IT.UTF-8 UTF-8/' /etc/locale.gen
  locale-gen
  localectl set-locale "LANG=en_US.UTF-8" "LC_TIME=it_IT.UTF-8" # LANG sets all LC_* if not set yet
  # keymap
  localectl set-keymap it
  # clock
  timedatectl set-ntp 1
  timedatectl set-local-rtc 1
}

set_hostname() {
  echo -e "\nSETTING HOSTNAMES..." && sleep 3
  echo "$MY_HOSTNAME" >/etc/hostname
  {
    echo "127.0.0.1   localhost"
    echo "::1         localhost"
    echo "127.0.1.1   $MY_HOSTNAME.localdomain $MY_HOSTNAME"
  } >/etc/hosts
}

download_packages() {
  echo -e "\nDOWNLOADING MAIN PACMAN PACKAGES..." && sleep 3
  sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
  sed -i 's/^#Color/Color/' /etc/pacman.conf
  #sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

  chmod +r /etc/pacman.d/mirrorlist
  reflector -c Italy -a24 -n5 -f5 -l5 --sort rate --save /etc/pacman.d/mirrorlist

  pacman -S --needed --noconfirm git efibootmgr grub grub-btrfs os-prober mtools dosfstools gvfs gvfs-smb nfs-utils ntfs-3g \
    reflector rsync networkmanager network-manager-applet iw wireless_tools wpa_supplicant dialog nftables firewalld openssh keychain nss-mdns \
    bluez bluez-utils wget inetutils dnsutils ipset dmidecode avahi bind sof-firmware \
    cups{,-pdf} cron bash-completion pkgstats arch-wiki-lite tlp acpid acpi acpi_call \
    alsa-{utils,plugins,firmware} pamixer pipewire{,-alsa,-pulse,-jack} xdg-{user-dirs,utils} \
    neovim alacritty exa firefox rclone ripgrep tree # immediate utility
}

btrfs_mkinitcpio() {
  echo -e "\nRUNNING mkinitcpio..." && sleep 3
  # MODULES=() ---> MODULES=(btrfs)
  sed -i 's/MODULES=()/MODULES=(btrfs)/' /etc/mkinitcpio.conf
  # HOOKS=(... filesystems ...) ---> HOOKS=(... encrypt filesystems ...)
  # fsck
  sed -i 's/HOOKS=(.\+)/HOOKS=(base udev block autodetect keyboard keymap modconf encrypt filesystems)/' /etc/mkinitcpio.conf
  mkinitcpio -P
}

install_bootloader() {
  echo -e "\nINSTALLING BOOTLOADER (GRUB)..." && sleep 3
  grub-install --recheck --target=x86_64-efi --efi-directory=/boot --bootloader-id="Arch Linux" "$DISK" && grub-mkconfig -o /boot/grub/grub.cfg
  # LUKS root: GRUB_CMDLINE_LINUX_DEFAULT="... cryptdevice=UUID=$rootUUID:cryptroot root=/dev/mapper/cryptroot"
  rootUUID="$(blkid -s UUID -o value "${DISK}2")"
  sed -i "s/^#\?GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"cryptdevice=UUID=$rootUUID:cryptroot root=\/dev\/mapper\/cryptroot rootfstype=btrfs quiet splash\"/" /etc/default/grub
  unset rootUUID
  sed -i 's/^#\?GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
  grub-mkconfig -o /boot/grub/grub.cfg
}

enable_services() {
  echo -e "\nENABLING SYSTEM SERVICES..." && sleep 3
  systemctl enable reflector.timer
  systemctl enable fstrim.timer
  systemctl enable NetworkManager
  systemctl enable acpid
  systemctl enable tlp
  systemctl enable avahi-daemon
  systemctl enable firewalld
  systemctl enable sshd
  systemctl enable cups
}

add_user() {
  echo -e "\nADDING USER..." && sleep 3
  useradd -m -G wheel -s /bin/bash "$MY_USERNAME"
  echo "$MY_USERNAME:$PASSWORD" | chpasswd
  # enable sudo rights
  sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
  # echo -e "\n$MY_USERNAME ALL=(ALL:ALL) ALL" >>"/etc/sudoers.d/$MY_USERNAME"
  # sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
  # disable no-password sudo rights
  # sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
  # sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
}

timezone_and_localization
set_hostname
download_packages
btrfs_mkinitcpio
install_bootloader
enable_services
add_user

echo -e "\nCOPYING REPO..." && sleep 3
cp -R auto-arch/ "home/$MY_USERNAME/"
chown -R "$MY_USERNAME": "home/$MY_USERNAME/auto-arch/"

exit
