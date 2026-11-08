#!/usr/bin/env bash
# Makine imajı: ortak nos imajının üzerine bir makinenin sürücülerini ve ayarlarını ekler
# (machines/Containerfile). Makine klasöründe:
#   packages.txt  kurulacak paketler (her satıra bir paket, # sonrası yorum)
#   services.txt  etkinleştirilecek servisler (aynı biçim)
#   system_files/ köke olduğu gibi kopyalanan dosyalar
#
# Ortak imaj bootc için son hazırlığı (bootc-rootfs.sh) zaten yaptı; burada sadece yeni
# paketlerin bıraktıkları toparlanır. initramfs yeniden üretilmiyor: makine paketleri
# initrd'ye girmemeli (NVIDIA 40-nos-omit.conf ile zaten dışarıda).
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

# Yeni paketlerin /var klasörleri (ortak imajınkiler nos-var.conf'ta).
bash /ctx/var-tmpfiles.sh "/usr/lib/tmpfiles.d/nos-var-$machine.conf"

# Sürüm: ortak imajın tarihi makine build'inin tarihiyle değiştirilir (bootc açılış menüsü).
sed -i "s/^VERSION_ID=.*/VERSION_ID=$(date -u +%Y%m%d)/" /usr/lib/os-release

# bootc-rootfs.sh'deki temizliğin paket kurulumundan etkilenen kısmı.
find /var -mindepth 1 -delete
rm -rf /usr/lib/sysimage/log /boot/*
