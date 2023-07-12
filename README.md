# auto-arch

Automated Arch Linux installation

## Features
- For both legacy BIOS & UEFI firmware
- LUKS-encrypted BTRFS root
- zRAM swapping

## Steps
1. Boot with UEFI and *disabled* secure boot
2. `git clone https://github.com/honeypot25/auto-arch`
3. `cd auto-arch && chmod +x *.sh`
4. `./start.sh`
