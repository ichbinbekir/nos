#!/usr/bin/env bash
# Makine imajı: ortak nos imajının üzerine bir makinenin sürücülerini ve ayarlarını ekler
# (machines/Containerfile). Makine klasöründe:
#   packages.txt  kurulacak paketler (her satıra bir paket, # sonrası yorum)
#   services.txt  etkinleştirilecek servisler (aynı biçim)
#   system_files/ köke olduğu gibi kopyalanan dosyalar
#
# Ortak imaj bootc için son hazırlığı (bootc-rootfs.sh) zaten yaptı; burada sadece yeni
# paketler eklenir ve bıraktıkları toparlanır. initramfs ortak imajdaki olarak kalıyor
# (yeniden üretmek build'i ~1 dk uzatıyordu): makine paketleri initrd'ye girmemeli
# (NVIDIA 40-nos-omit.conf ile dışarıda; işlemci mikrokodları ortak imajda). Bir makine
# initrd'de bir şey isterse burada `bash /ctx/bootc/initramfs.sh` çağrılmalı; os-release'teki
# VERSION_ID'yi önce çıkarıp sonra eklemek gerekir (bkz. Containerfile).
#
# Kullanım: machine.sh <makine adı>

set -xeuo pipefail

machine="${1:?makine adı verilmedi}"
dir="/ctx/machines/$machine"
[[ -d $dir ]] || { echo "Makine klasörü yok: $dir" >&2; exit 1; }

# Satırlardan yorumları ve boşlukları ayıklar.
list() { [[ -f $1 ]] && sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' "$1" || true; }

# Paket veritabanı bilerek güncellenmiyor (-y yok): ortak imajın kurulduğu veritabanıyla
# aynı sürümler gelsin. Özellikle nvidia-open çekirdeğin tam sürümü için derlendiği için
# yeni bir veritabanı çekirdekle uyuşmayan bir sürüm getirebilirdi. Makine build'i CI'da
# ortak imajın hemen ardından çalışıyor.
mapfile -t packages < <(list "$dir/packages.txt")
if ((${#packages[@]})); then
  pacman -S --noconfirm --needed "${packages[@]}"
fi

if [[ -d $dir/system_files ]]; then
  cp -avf "$dir/system_files/." /
fi

mapfile -t services < <(list "$dir/services.txt")
if ((${#services[@]})); then
  systemctl enable "${services[@]}"
fi

find /etc -name '*.pacnew' -delete

# Donanım veritabanı (hwdb.bin) paket kurulumunda yeniden üretiliyor ve tarihi build anı
# oluyor; içerik aynı olsa da imajın katmanı her gün değişip yeniden iniyordu. Tarihi,
# kaynak dosyalarının (hwdb.d) en yenisine sabitlenir.
touch -d "@$(stat -c %Y /usr/lib/udev/hwdb.d/* | sort -n | tail -n1)" /usr/lib/udev/hwdb.bin

# Yeni paketlerin /var klasörleri (ortak imajınkiler nos-var.conf'ta).
bash /ctx/var-tmpfiles.sh "/usr/lib/tmpfiles.d/nos-var-$machine.conf"

# Görünen ad makineyi de söylesin (açılış menüsü, fastfetch, KDE "Bu Sistem Hakkında"):
# "nos-nitro". NAME/ID "nos" kalıyor. Sürüm makine build'inin tarihi. initrd'deki os-release
# ortak imajınki olarak kalıyor; bootc menü adını kök dosya sistemindekinden alıyor.
sed -i -e "s/^PRETTY_NAME=.*/PRETTY_NAME=\"nos-$machine\"/" -e '/^VARIANT_ID=/d' \
  -e "s/^VERSION_ID=.*/VERSION_ID=$(date -u +%Y%m%d)/" /usr/lib/os-release
echo "VARIANT_ID=$machine" >>/usr/lib/os-release

# bootc-rootfs.sh'deki temizliğin paket kurulumundan etkilenen kısmı.
find /var -mindepth 1 -delete
rm -rf /usr/lib/sysimage/log /boot/*
