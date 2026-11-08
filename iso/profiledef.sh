#!/usr/bin/env bash
# shellcheck disable=SC2034
# nos kurulum ISO'su (archiso). Arch'ın "releng" profilinden sadeleştirildi: sadece UEFI
# (nos systemd-boot ile açılıyor, BIOS'ta çalışmaz), sadece kurulum için gereken paketler.
# Açılınca tty1'de kurulum programı (/usr/local/bin/nos-install) başlar.

iso_name="nos-installer"
iso_label="NOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="nos <https://github.com/ichbinbekir/nos>"
iso_application="nos kurulum ortamı"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
bootmodes=('uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/usr/local/bin/nos-install"]="0:0:755"
)
