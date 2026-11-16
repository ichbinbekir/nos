#!/usr/bin/env bash
# Bir katmanı imaja uygular: ortak imaj (core/), makineler (machines/<makine>/), ileride
# masaüstleri. Katman klasöründe (hepsi isteğe bağlı):
#   packages.txt  kurulacak paketler (her satıra bir paket, # sonrası yorum)
#   aur.txt       AUR paketleri (aynı biçim); aur-builder aşamasında derlenir (aur.sh) ve
#                 /aur'dan kurulur. Şimdilik sadece ortak imajda (core/Containerfile /aur'u bağlıyor).
#   system_files/ köke olduğu gibi kopyalanan dosyalar
#   services.txt  etkinleştirilecek servisler (aynı biçim)
#   setup.sh      listelere sığmayan işler; en son çalışır
#
# Kullanım: layer.sh <katman klasörü> <ad>
# <ad>, /var klasörlerinin yazıldığı tmpfiles.d dosyasının adında: nos-var-<ad>.conf.

set -xeuo pipefail

dir="${1:?katman klasörü verilmedi}"
name="${2:?katman adı verilmedi}"
[[ -d $dir ]] || { echo "Katman klasörü yok: $dir" >&2; exit 1; }

# Satırlardan yorumları ve boşlukları ayıklar.
list() { [[ -f $1 ]] && sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' "$1" || true; }

# Paket veritabanı burada güncellenmiyor (-y yok). Ortak imajda core/Containerfile bunu hemen
# önce yapıyor. Makine imajlarında bilerek: ortak imajın kurulduğu veritabanıyla aynı
# sürümler gelsin. Özellikle nvidia-open çekirdeğin tam sürümü için derlendiği için yeni bir
# veritabanı çekirdekle uyuşmayan bir sürüm getirebilirdi. Makine build'i CI'da ortak
# imajın hemen ardından çalışıyor.
mapfile -t packages < <(list "$dir/packages.txt")
if ((${#packages[@]})); then
  pacman -S --noconfirm --needed "${packages[@]}"
fi

if [[ -f $dir/aur.txt ]]; then
  [[ -d /aur ]] || { echo "AUR paketleri derlenmemiş (/aur yok)" >&2; exit 1; }
  find /aur -name '*.pkg.tar.zst' ! -name '*-debug-*' -print0 | xargs -0 pacman -U --noconfirm
fi

# Paketlerden sonra: bir paketin kendi dosyasının yerine konan ayarlar (ör. /etc/environment)
# paket kurulumunda ezilmesin.
if [[ -d $dir/system_files ]]; then
  cp -avf "$dir/system_files/." /
fi

mapfile -t services < <(list "$dir/services.txt")
if ((${#services[@]})); then
  systemctl enable "${services[@]}"
fi

if [[ -f $dir/setup.sh ]]; then
  bash "$dir/setup.sh"
fi

# Arch Docker imajının kendi ayarları korunurken pacman yeni sürümleri .pacnew olarak
# bırakıyor; gerekmiyorlar.
find /etc -name '*.pacnew' -delete

# Donanım veritabanı (hwdb.bin) paket kurulumunda yeniden üretiliyor ve tarihi build anı
# oluyor; içerik aynı olsa da imajın katmanı her gün değişip yeniden iniyordu. Tarihi,
# kaynak dosyalarının (hwdb.d) en yenisine sabitlenir.
touch -d "@$(stat -c %Y /usr/lib/udev/hwdb.d/* | sort -n | tail -n1)" /usr/lib/udev/hwdb.bin

# Paketlerin /var altına koyduğu klasörler açılışta oluşturulsun (bkz. var-tmpfiles.sh).
bash "$(dirname "$0")/var-tmpfiles.sh" "/usr/lib/tmpfiles.d/nos-var-$name.conf"
