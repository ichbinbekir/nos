FROM ghcr.io/ublue-os/base-nvidia:latest

# /var/cache, /var/log ve /tmp mount edildiği için dnf önbelleği ve logları imaja girmez.
# Mount edilmeyen /run/dnf ve /var/lib/dnf/repos ise elle temizlenir.
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    dnf5 -y install \
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
      ark \
      spectacle \
      flatpak-kcm \
      kwrite \
      gwenview \
      kde-connect \
      plasma-systemmonitor \
      kinfocenter \
      plasma-disks \
    && rm -rf /run/dnf /var/lib/dnf/repos \
    && systemctl enable sddm.service \
    && systemctl disable sshd.service \
    && firewall-offline-cmd --remove-service-from-zone=ssh \
    && firewall-offline-cmd --add-service=kdeconnect \
    && rm -f /etc/firewalld/zones/*.old

RUN bootc container lint
