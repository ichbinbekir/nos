#!/usr/bin/env bash
# Ortak imajın listelere sığmayan işleri. scripts/layer.sh paketleri kurup system_files'ı
# kopyaladıktan ve servisleri açtıktan sonra çağırır. Sabit içerikli ayarlar burada değil,
# system_files'ta düz dosya olarak durur; burada sadece üretilmesi ya da bir paket dosyasında
# küçük bir değişiklik gereken ayarlar var.

set -xeuo pipefail

# distrobox 1.8.2.5 hatası: salt okunur klasörleri "ro:rslave" ile bağlıyor, podman bunu
# reddediyor ("incorrect volume format"), kutu oluşturulamıyor. Doğrusu "ro,rslave"
# (upstream'de düzeltildi, distrobox#2083; düzeltilmiş sürüm çıkmadı). Hata, crun'ın
# podman info'daki bir satırında "runc" geçtiği için distrobox'ın runc yolunu seçmesiyle
# ortaya çıkıyor. Düzeltilmiş sürüm gelince satır bulunmaz, adım kendiliğinden atlanır.
if grep -qF ':ro${rslave}"' /usr/bin/distrobox-create; then
  sed -i 's|:ro\${rslave}"|:ro,rslave"|' /usr/bin/distrobox-create
  grep -qF ':ro,rslave"' /usr/bin/distrobox-create
fi

# espanso Wayland'de klavyeyi /dev/input'tan okuyor; bunun için kendi kurulum betiği bu izni
# veriyor. Paket betiği değişirse diye açıkça verilir ve günlüğe yazılır (izin imaj katmanlarında
# korunuyor; kwin_wayland'in izni de aynı yoldan geliyor).
setcap cap_dac_override+p /usr/bin/espanso
getcap /usr/bin/espanso

# git dosya izinlerini taşımıyor; sudo bu izin olmadan dosyayı okumaz.
chmod 0440 /etc/sudoers.d/10-wheel

# Yerel ayarlar. Hangisinin kullanılacağı kurulumda seçilir.
sed -i -e 's/^#\(en_US.UTF-8 UTF-8\)/\1/' -e 's/^#\(tr_TR.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen

# İlk açılış: system_files/etc/machine-id "uninitialized" olduğu için sistem ilk açılışı
# algılar; soruları nos-firstboot soruyor. Aynı işi yarım yapan systemd-firstboot kapatılır.
systemctl mask systemd-firstboot.service
systemctl set-default graphical.target

# Güvenlik duvarı (ufw): Gelen bağlantılar varsayılan olarak kapalı, giden açık.
# Sadece KDE Connect'in portları açılır. ufw build sırasında çalışmadığı için kurallar
# sadece dosyalara yazılır; ENABLED=yes ile açılışta ufw.service onları uygular.
ufw default deny incoming
ufw default allow outgoing
ufw allow 1714:1764/tcp comment 'KDE Connect'
ufw allow 1714:1764/udp comment 'KDE Connect'
# Sanal makinelerin ağı (libvirt'in "default" NAT ağı, virbr0): gelen kapalı olduğu için
# sanal makineler bilgisayardaki dnsmasq'tan IP (DHCP) ve DNS alamıyordu; ufw yönlendirmeyi
# de varsayılan olarak engellediği için internete çıkamıyorlardı. Sadece virbr0'a izin verilir.
ufw allow in on virbr0 comment 'libvirt: DHCP/DNS'
ufw route allow in on virbr0 comment 'libvirt: sanal makine -> internet'
ufw route allow out on virbr0 comment 'libvirt: internet -> sanal makine'
sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf

# Sistem adı (system_files/usr/lib/os-release): /etc/os-release ona bağlantı olmalı;
# Arch Docker imajı onu düz dosyaya çeviriyor. Git ve Windows sembolik bağlantıları
# güvenilir taşımadığı için bağlantı burada oluşturulur.
ln -sf ../usr/lib/os-release /etc/os-release

# libvirt'in hazır "default" NAT ağı (paketle gelen tanım) servis başlayınca kendiliğinden
# açılsın; sanal makineler ek ayar yapmadan internete çıkar (virsh net-autostart default).
ln -sf ../default.xml /etc/libvirt/qemu/networks/autostart/default.xml
