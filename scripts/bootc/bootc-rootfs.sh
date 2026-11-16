#!/usr/bin/env bash
# Source: bootcrew/mono shared/bootc-rootfs.sh (Apache-2.0, see LICENSE).
# Change: /opt is not redirected to /var/opt; it stays a real directory inside the image.
# AUR packages (e.g. helium-browser-bin) install to /opt; if /opt were redirected to /var
# these files would be deleted.

set -xeuo pipefail

rm -rf /boot /home /root /usr/local /srv /mnt /var /usr/lib/sysimage/log /usr/lib/sysimage/cache/pacman/pkg

mkdir -p /sysroot /boot /usr/lib/ostree /var

ln -sT sysroot/ostree /ostree && ln -sT var/roothome /root && ln -sT var/srv /srv && ln -sT var/mnt /mnt && ln -sT var/home /home && ln -sT ../var/usrlocal /usr/local

echo "$(for dir in home srv mnt usrlocal ; do echo "d /var/$dir 0755 root root -" ; done)" | tee -a "/usr/lib/tmpfiles.d/bootc-base-dirs.conf"

printf "d /var/roothome 0700 root root -\nd /run/media 0755 root root -" | tee -a "/usr/lib/tmpfiles.d/bootc-base-dirs.conf"

printf '[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n' | tee "/usr/lib/ostree/prepare-root.conf"
