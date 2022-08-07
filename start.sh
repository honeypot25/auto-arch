#!/bin/bash

set -e

set -a
STARTDIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
set +a

# scripts
for script in "$STARTDIR"/*.sh; do
  chmod +x "$script"
done

echo -e "\nEXECUTING \"0-setup.sh\"..." && sleep 2
bash "$STARTDIR/0-setup.sh"

echo -e "\nEXECUTING \"1-base.sh\" (chroot)..." && sleep 2
arch-chroot /mnt "auto-arch/1-base.sh"

source "$STARTDIR/cfg"
if [ "$DOTFILES_NEEDED" = "y" ]; then
  echo -e "\nEXECUTING \"2-dotfiles.sh\" (chroot)..." && sleep 2
  arch-chroot /mnt /usr/bin/runuser -u "$MY_USERNAME" -- "home/$MY_USERNAME/auto-arch/2-dotfiles.sh"
fi

while [[ ! "$delete_all" =~ ^y|n$ ]]; do
  echo
  read -rp "Do you want to delete all the repo dirs? (y|n): " delete_all
done
[ "$delete_all" = "y" ] && {
  echo -e "\nDELETING ALL COPIED REPOS..." && sleep 2
  # delete the repo copied in /mnt by 0-setup.sh
  rm -rfv /mnt/auto-arch/
  # and the one copied in the user's home by 1-base.sh
  rm -rfv "/mnt/home/$MY_USERNAME/auto-arch/"
  # and the current one (start.sh)
  cd .. && rm -rfv "$STARTDIR"
  umount -R /mnt
}

sync
echo -e "\nALL DONE! REBOOTING IN:\n"
for sec in {10..1}; do
  printf "%s...\n" "$sec"
  sleep 1
done
reboot
