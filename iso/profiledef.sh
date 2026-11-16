#!/usr/bin/env bash
# shellcheck disable=SC2034
# nos installer ISO (archiso). Trimmed down from Arch's "releng" profile: UEFI only
# (nos boots with systemd-boot, it doesn't work on BIOS), only the packages needed to install.
# On boot the installer (/usr/local/bin/nos-install) starts on tty1.

iso_name="nos-installer"
iso_label="NOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="nos <https://github.com/ichbinbekir/nos>"
iso_application="nos installer environment"
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
