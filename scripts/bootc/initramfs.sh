#!/usr/bin/env bash
# Kaynak: bootcrew/mono shared/initramfs.sh (Apache-2.0, bkz. LICENSE).
# Değişiklik: initramfs'in ve içindeki dosyaların tarihi çekirdeğin paket tarihine
# sabitleniyor (SOURCE_DATE_EPOCH + touch). Yoksa dosya her build'de "şimdi" tarihli
# çıkıyor, içerik aynı olsa da imajın katmanı değişip her güncellemede ~60 MB iniyordu.

set -xeuo pipefail

mkdir -p /usr/lib/dracut/dracut.conf.d/
printf "systemdsystemconfdir=/etc/systemd/system\nsystemdsystemunitdir=/usr/lib/systemd/system\n" | tee /usr/lib/dracut/dracut.conf.d/30-bootcrew-fix-bootc-module.conf
printf 'reproducible=yes\nhostonly=no\ncompress=zstd\nadd_dracutmodules+=" bootc "' | tee "/usr/lib/dracut/dracut.conf.d/30-bootcrew-bootc-container-build.conf"
kdir="$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)"
SOURCE_DATE_EPOCH="$(stat -c %Y "${kdir}/vmlinuz")"
export SOURCE_DATE_EPOCH
dracut --force "${kdir}/initramfs.img"
touch -h -d "@${SOURCE_DATE_EPOCH}" "${kdir}/initramfs.img"
