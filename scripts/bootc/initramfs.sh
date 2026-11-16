#!/usr/bin/env bash
# Source: bootcrew/mono shared/initramfs.sh (Apache-2.0, see LICENSE).
# Change: the date of the initramfs and the files inside it is pinned to the kernel package's
# date (SOURCE_DATE_EPOCH + touch). Otherwise the file was dated "now" on every build, and even
# with identical content the image layer changed and ~60 MB was downloaded on every update.

set -xeuo pipefail

mkdir -p /usr/lib/dracut/dracut.conf.d/
printf "systemdsystemconfdir=/etc/systemd/system\nsystemdsystemunitdir=/usr/lib/systemd/system\n" | tee /usr/lib/dracut/dracut.conf.d/30-bootcrew-fix-bootc-module.conf
printf 'reproducible=yes\nhostonly=no\ncompress=zstd\nadd_dracutmodules+=" bootc "' | tee "/usr/lib/dracut/dracut.conf.d/30-bootcrew-bootc-container-build.conf"
kdir="$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)"
SOURCE_DATE_EPOCH="$(stat -c %Y "${kdir}/vmlinuz")"
export SOURCE_DATE_EPOCH
dracut --force "${kdir}/initramfs.img"
touch -h -d "@${SOURCE_DATE_EPOCH}" "${kdir}/initramfs.img"
