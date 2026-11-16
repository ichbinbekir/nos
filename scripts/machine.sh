#!/usr/bin/env bash
# Machine image (machines/Containerfile): adds the machine's layer (machines/<machine>/:
# packages, services, system_files; see layer.sh) on top of the shared nos image, sets its name
# and cleans up what it leaves behind.
#
# The shared image already did the final bootc preparation (bootc/bootc-rootfs.sh). The
# initramfs stays the shared image's (regenerating it made the build ~1 min longer): machine
# packages shouldn't go into the initrd (NVIDIA is left out via 40-nos-omit.conf; CPU microcode
# is in the shared image). If a machine needs something in the initrd, call
# `bash /ctx/scripts/bootc/initramfs.sh` here; VERSION_ID in os-release must be removed first and
# added back afterwards (see core/Containerfile).
#
# Usage: machine.sh <machine name>

set -xeuo pipefail

machine="${1:?no machine name given}"

bash "$(dirname "$0")/layer.sh" "/ctx/machines/$machine" "$machine"

# Make the display name include the machine (boot menu, fastfetch, KDE "About this System"):
# "nos-nitro". NAME/ID stay "nos". The version is the machine build date. The os-release in
# the initrd stays the shared image's; bootc takes the menu name from the root filesystem's.
sed -i -e "s/^PRETTY_NAME=.*/PRETTY_NAME=\"nos-$machine\"/" -e '/^VARIANT_ID=/d' \
  -e "s/^VERSION_ID=.*/VERSION_ID=$(date -u +%Y%m%d)/" /usr/lib/os-release
echo "VARIANT_ID=$machine" >>/usr/lib/os-release

# The part of bootc-rootfs.sh's cleanup that package installation affects.
find /var -mindepth 1 -delete
rm -rf /usr/lib/sysimage/log /boot/*
