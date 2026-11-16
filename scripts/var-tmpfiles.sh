#!/usr/bin/env bash
# /var imaja girmiyor: bootc-rootfs.sh (makine imajında machine.sh) boşaltıyor, bootc da
# kurulu sistemlerde /var'a dokunmuyor. Paketlerin /var altına koyduğu klasörler (ör.
# /var/lib/libvirt, /var/log/swtpm) bu yüzden kurulu sistemde yoktu; libvirt bu yüzden
# açılmıyordu. Fedora'da rpm-ostree bunu kendiliğinden yapıyor, burada elle: her klasör
# sahibi ve izniyle tmpfiles.d satırına çevrilir, açılışta systemd-tmpfiles eksikleri
# oluşturur. Zaten klasörü oluşturan bir tmpfiles.d satırı (d, D, v, q, Q, C, L) olan
# yollar ve pacman'ın kendi klasörleri atlanır. Sadece izin düzelten satırlar (z, Z; ör.
# swtpm'in /var/lib/swtpm-localca'sı) klasörü oluşturmadığı için onlar sayılmaz.
#
# Kullanım: var-tmpfiles.sh <yazılacak tmpfiles.d dosyası>

set -euo pipefail

out="$1"
declared="$(systemd-tmpfiles --cat-config 2>/dev/null | awk '$1 ~ /^[dDvqQCL]/ && NF >= 2 {print $2}' | sort -u)"
find /var -mindepth 1 -type d \
  ! -path '/var/lib/pacman*' ! -path '/var/cache/pacman*' ! -path '/var/log/journal*' ! -path '/var/tmp*' \
  -printf '%p %m %u %g\n' | sort |
  while read -r path mode user group; do
    grep -qxF "$path" <<<"$declared" && continue
    printf 'd %s %04o %s %s -\n' "$path" "0$mode" "$user" "$group"
  done > "$out"
echo "== $out"
cat "$out"
