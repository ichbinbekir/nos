#!/usr/bin/env bash
# İmajın asıl içeriği: paketler, servisler ve ayarlar.
# Kurallar (bkz. README.md ve CLAUDE.md): Hafif ve sahibinin donanımına (Acer Nitro 16: Intel i7-13620H,
# NVIDIA RTX 4050) yönelik. Başka donanıma özel paketler (ör. amd-ucode) eklenmez;
# Linux'ta normalde bulunan genel araçlar ise kalır.

set -xeuo pipefail

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
  btrfs-progs # initramfs.sh'den önce kurulu olmalı (btrfs diskten açılış)
  e2fsprogs
  xfsprogs
  dosfstools
  ntfs-3g # Windows bölümleri ve NTFS diskler
  dbus
  dbus-glib
  glib2
  shadow

  # NVIDIA (linux kerneli için önceden derlenmiş)
  nvidia-open
  nvidia-utils

  # Hibrit grafik (dizüstü: Intel tümleşik + NVIDIA). Masaüstü Intel ile çalışır,
  # NVIDIA sadece istenen uygulamalarda devreye girer.
  nvidia-prime # prime-run <uygulama>: uygulamayı NVIDIA ile çalıştırır
  switcheroo-control # KDE'de sağ tık > "Ayrık grafik kartıyla çalıştır"
  vulkan-intel # Intel için Vulkan
  intel-media-driver # Intel ile donanımsal video çözme (VA-API; Broadwell ve sonrası)
  zram-generator # Sıkıştırılmış RAM takası (ayarı system_files'ta)
  plymouth # Açılışta yazılar yerine sade animasyon (bgrt teması: üretici logosu + dönen simge). initramfs.sh'den önce kurulu olmalı

  # Sistem
  sudo
  git
  vim
  openssh # sshd açılmıyor, sadece istemci olarak kullanılıyor
  man-db
  htop
  unzip
  lm_sensors # Isı sensörleri (htop, KDE Sistem İzleyici; sensors komutu)
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
  sof-firmware # Intel dahili ses kartı (Sound Open Firmware); bu olmadan ses çalışmıyor
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
  plasma-firewall # Sistem Ayarları'nda ufw sayfası
  snapper # Ev dizininin otomatik snapshot'ları (ayarı nos-firstboot yapıyor)
  btrfs-assistant # Snapshot'ları ve btrfs'i grafik arayüzden yönetme

  # Araçlar
  fish
  fastfetch
  distrobox
  podman
  python
  gum # İlk kurulum ekranının (nos-firstboot) arayüzü
)

pacman -S --noconfirm --needed "${PACKAGES[@]}"

# AUR paketleri (aur.sh tarafından derlendi). Bağımlılıkları depolardan gelir.
find /aur -name '*.pkg.tar.zst' ! -name '*-debug-*' -print0 | xargs -0 pacman -U --noconfirm

# system_files/ köke kopyalanır. Paketlerden sonra yapılır ki bir paketin kendi dosyasının
# yerine koyduğumuz ayarlar (ör. /etc/environment) paket kurulumunda ezilmesin.
# Sabit içerikli ayarlar burada değil, system_files'ta düz dosya olarak durur; bu betikte
# sadece üretilmesi ya da bir paket dosyasında küçük bir değişiklik gereken ayarlar var.
cp -avf /ctx/system_files/. /
# git dosya izinlerini taşımıyor; sudo bu izin olmadan dosyayı okumaz.
chmod 0440 /etc/sudoers.d/10-wheel

# Yerel ayarlar. Hangisinin kullanılacağı ilk açılışta nos-firstboot ile seçilir.
sed -i -e 's/^#\(en_US.UTF-8 UTF-8\)/\1/' -e 's/^#\(tr_TR.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen

# İlk açılış: system_files/etc/machine-id "uninitialized" olduğu için sistem ilk açılışı
# algılar; soruları nos-firstboot soruyor. Aynı işi yarım yapan systemd-firstboot kapatılır.
systemctl mask systemd-firstboot.service

systemctl enable \
  sddm.service \
  NetworkManager.service \
  bluetooth.service \
  ufw.service \
  power-profiles-daemon.service \
  switcheroo-control.service \
  nvidia-powerd.service \
  systemd-resolved.service \
  systemd-timesyncd.service \
  nos-firstboot.service \
  nos-update.timer \
  fstrim.timer \
  snapper-timeline.timer \
  snapper-cleanup.timer \
  NetworkManager-wait-online.service # nos-update internet bağlantısını beklesin diye
systemctl set-default graphical.target

# Güvenlik duvarı (ufw): Gelen bağlantılar varsayılan olarak kapalı, giden açık.
# Sadece KDE Connect'in portları açılır. ufw build sırasında çalışmadığı için kurallar
# sadece dosyalara yazılır; ENABLED=yes ile açılışta ufw.service onları uygular.
ufw default deny incoming
ufw default allow outgoing
ufw allow 1714:1764/tcp comment 'KDE Connect'
ufw allow 1714:1764/udp comment 'KDE Connect'
sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf

# Sistem adı (system_files/usr/lib/os-release): /etc/os-release ona bağlantı olmalı;
# Arch Docker imajı onu düz dosyaya çeviriyor. Git ve Windows sembolik bağlantıları
# güvenilir taşımadığı için bağlantı burada oluşturulur.
ln -sf ../usr/lib/os-release /etc/os-release

# NoExtract kaldırılıp paketler yeniden kurulunca pacman, Docker imajının kendi
# ayarlarını korumak için yeni sürümleri .pacnew olarak bırakıyor; gerekmiyorlar.
find /etc -name '*.pacnew' -delete
