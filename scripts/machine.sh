#!/usr/bin/env bash
# Makine imajı (machines/Containerfile): ortak nos imajının üzerine makinenin katmanını
# (machines/<makine>/: paketler, servisler, system_files; bkz. layer.sh) ekler, adını yazar
# ve bıraktıklarını toparlar.
#
# Ortak imaj bootc için son hazırlığı (bootc/bootc-rootfs.sh) zaten yaptı. initramfs ortak
# imajdaki olarak kalıyor (yeniden üretmek build'i ~1 dk uzatıyordu): makine paketleri
# initrd'ye girmemeli (NVIDIA 40-nos-omit.conf ile dışarıda; işlemci mikrokodları ortak
# imajda). Bir makine initrd'de bir şey isterse burada `bash /ctx/scripts/bootc/initramfs.sh`
# çağrılmalı; os-release'teki VERSION_ID'yi önce çıkarıp sonra eklemek gerekir (bkz. Containerfile).
#
# Kullanım: machine.sh <makine adı>

set -xeuo pipefail

machine="${1:?makine adı verilmedi}"

bash "$(dirname "$0")/layer.sh" "/ctx/machines/$machine" "$machine"

# Görünen ad makineyi de söylesin (açılış menüsü, fastfetch, KDE "Bu Sistem Hakkında"):
# "nos-nitro". NAME/ID "nos" kalıyor. Sürüm makine build'inin tarihi. initrd'deki os-release
# ortak imajınki olarak kalıyor; bootc menü adını kök dosya sistemindekinden alıyor.
sed -i -e "s/^PRETTY_NAME=.*/PRETTY_NAME=\"nos-$machine\"/" -e '/^VARIANT_ID=/d' \
  -e "s/^VERSION_ID=.*/VERSION_ID=$(date -u +%Y%m%d)/" /usr/lib/os-release
echo "VARIANT_ID=$machine" >>/usr/lib/os-release

# bootc-rootfs.sh'deki temizliğin paket kurulumundan etkilenen kısmı.
find /var -mindepth 1 -delete
rm -rf /usr/lib/sysimage/log /boot/*
