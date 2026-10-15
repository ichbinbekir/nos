FROM ghcr.io/ublue-os/base-nvidia:latest

# /var/cache, /var/log ve /tmp mount edildiği için dnf önbelleği ve logları imaja girmez.
# Mount edilmeyen /run/dnf ve /var/lib/dnf/repos ise elle temizlenir.
# Discover'ın PackageKit eklentileri hariç tutulur: imaj bootc ile güncellendiği için
# Discover sadece Flatpak'leri yönetir.
# bluez'den python3'e kadarki paketler temel imajda zaten var; doğrudan kullandığımız için
# temel imajdan çıkarılırlarsa da kurulsunlar diye listede.
# Paket kurulumu sırasında /run altında oluşan dizinler silinir ve tuned'ın /var/lib/tuned
# dizini için tmpfiles.d girdisi eklenir (bootc container lint uyarıları).
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    dnf5 -y install \
      --exclude=plasma-discover-packagekit,plasma-discover-offline-updates \
      bluez \
      NetworkManager-wifi \
      firewalld \
      flatpak \
      distrobox \
      python3 \
      fish \
      fastfetch \
      plasma-desktop \
      sddm \
      sddm-wayland-plasma \
      konsole \
      dolphin \
      bluedevil \
      plasma-nm \
      kwalletmanager5 \
      kscreen \
      sddm-kcm \
      kde-gtk-config \
      breeze-gtk \
      kdegraphics-thumbnailers \
      ffmpegthumbs \
      ark \
      spectacle \
      flatpak-kcm \
      plasma-discover \
      plasma-discover-flatpak \
      kwrite \
      gwenview \
      kde-connect \
      plasma-systemmonitor \
      kinfocenter \
      plasma-disks \
      tuned \
      tuned-ppd \
    && rm -rf /run/dnf /run/sddm /run/tuned /var/lib/dnf/repos \
    && echo 'd /var/lib/tuned 0755 root root - -' > /usr/lib/tmpfiles.d/nos-tuned.conf \
    && systemctl enable \
      sddm.service \
      NetworkManager.service \
      bluetooth.service \
      firewalld.service \
      tuned.service \
      tuned-ppd.service \
    && systemctl set-default graphical.target \
    && systemctl disable sshd.service \
    && firewall-offline-cmd --remove-service-from-zone=ssh \
    && firewall-offline-cmd --add-service=kdeconnect \
    && rm -f /etc/firewalld/zones/*.old

RUN bootc container lint
