#!/usr/bin/env bash
# İmajın asıl içeriği: paketler, servisler ve ayarlar.
# Kurallar (bkz. README.md ve CLAUDE.md): Hafif ve sahibinin donanımına (Intel işlemci,
# NVIDIA ekran kartı) yönelik. Başka donanıma özel paketler (ör. amd-ucode) eklenmez;
# Linux'ta normalde bulunan genel araçlar ise kalır.

set -xeuo pipefail

# system_files/ içeriği köke kopyalanır.
cp -avf /ctx/system_files/. /
chmod 0440 /etc/sudoers.d/10-wheel

# Resmi Arch Docker imajı yer kazanmak için man sayfalarını, belgeleri ve çevirileri
# kurmuyor (pacman.conf sonundaki NoExtract satırları). Normal bir Arch kurulumundaki
# gibi olsun diye bu satırlar silinir ve önceden kurulu paketler, eksik dosyaları
# gelsin diye yeniden kurulur.
sed -i '/^NoExtract/d' /etc/pacman.conf
pacman -Syu --noconfirm
pacman -Qqn | pacman -S --noconfirm -

PACKAGES=(
  # bootc ve önyükleme (bootcrew/mono)
  base
  linux
  linux-firmware
  intel-ucode
  dracut
  ostree
  bubblewrap
  skopeo
  btrfs-progs
  e2fsprogs
  xfsprogs
  dosfstools
  dbus
  dbus-glib
  glib2
  shadow

  # NVIDIA (linux kerneli için önceden derlenmiş)
  nvidia-open
  nvidia-utils

  # Sistem
  sudo
  git
  openssh # sshd açılmıyor, sadece istemci olarak kullanılıyor
  man-db
  networkmanager
  bluez
  bluez-utils
  ufw
  power-profiles-daemon
  pipewire
  pipewire-audio # Bluetooth ses desteği bu pakette
  pipewire-pulse
  pipewire-alsa
  pipewire-jack
  wireplumber
  noto-fonts
  noto-fonts-emoji

  # KDE Plasma
  plasma-desktop
  sddm
  sddm-kcm
  konsole
  dolphin
  bluedevil
  plasma-nm
  plasma-pa
  powerdevil
  kscreen
  xdg-desktop-portal-kde
  kwalletmanager
  kde-gtk-config
  breeze-gtk
  ffmpegthumbs
  kdegraphics-thumbnailers
  ark
  spectacle
  # Spectacle'ın ekran görüntüsündeki yazıyı okuma (OCR) özelliği için dil verisi.
  # Belirtilmezse pacman 128 dil arasından ilkini (Afrikaanca) seçiyor.
  tesseract-data-eng
  tesseract-data-tur
  flatpak
  flatpak-kcm
  discover
  kate # kwrite bu pakette
  gwenview
  kdeconnect
  plasma-systemmonitor
  kinfocenter
  plasma-disks

  # Araçlar
  fish
  fastfetch
  distrobox
  podman
  python
)

pacman -S --noconfirm --needed "${PACKAGES[@]}"

# AUR paketleri (aur.sh tarafından derlendi). Bağımlılıkları depolardan gelir.
find /aur -name '*.pkg.tar.zst' ! -name '*-debug-*' -print0 | xargs -0 pacman -U --noconfirm

# Yerel ayarlar. Hangisinin kullanılacağı ilk açılışta systemd-firstboot ile seçilir.
sed -i -e 's/^#\(en_US.UTF-8 UTF-8\)/\1/' -e 's/^#\(tr_TR.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen

# İlk açılışta systemd-firstboot dil, klavye, saat dilimi ve root şifresini sorar. machine-id "uninitialized" olunca sistem ilk açılışı algılar.
echo "uninitialized" >/etc/machine-id

systemctl enable \
  sddm.service \
  NetworkManager.service \
  bluetooth.service \
  ufw.service \
  power-profiles-daemon.service \
  systemd-resolved.service \
  systemd-timesyncd.service
systemctl set-default graphical.target

# Güvenlik duvarı (ufw): Gelen bağlantılar varsayılan olarak kapalı, giden açık.
# Sadece KDE Connect'in portları açılır. ufw build sırasında çalışmadığı için kurallar
# sadece dosyalara yazılır; ENABLED=yes ile açılışta ufw.service onları uygular.
ufw default deny incoming
ufw default allow outgoing
ufw allow 1714:1764/tcp comment 'KDE Connect'
ufw allow 1714:1764/udp comment 'KDE Connect'
sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf

# NoExtract kaldırılıp paketler yeniden kurulunca pacman, Docker imajının kendi
# ayarlarını korumak için yeni sürümleri .pacnew olarak bırakıyor; gerekmiyorlar.
find /etc -name '*.pacnew' -delete
