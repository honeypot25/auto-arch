#!/usr/bin/env bash

# using ()
install_dotfiles() (
  echo -e "\nSETTING ~/.dotfiles GIT BARE REPO..." && sleep 3
  pushd ~ || return
  git clone --bare https://github.com/honeypot25/dotfiles.git .dotfiles
  # set temp git alias. As a nested function, using {}
  dots() {
    /usr/bin/git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" "$@"
  }
  # try to checkout
  if ! dots checkout; then
    echo -e "Backing up pre-existing dotfiles...\n"
    mkdir -p .dotfiles.bak
    dots checkout 2>&1 | grep -E "\s+\." | awk '{ print $1 }' | xargs -I{} mv {} .dotfiles.bak/{}
  fi
  # now checkout
  dots checkout && echo -e "Checked out config\n"
  dots config --local status.showUntrackedFiles no
  # make scripts executable
  # chmod u+x .bin/*
  # chmod u+x .system_setup.sh
  echo -e "\n~/.dotfiles ready!"
  popd || return # $PWD
)

install_dotfiles

exit
