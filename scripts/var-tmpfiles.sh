#!/usr/bin/env bash
# /var is not part of the image: bootc-rootfs.sh (machine.sh in machine images) empties it, and
# bootc doesn't touch /var on installed systems. So folders packages put under /var (e.g.
# /var/lib/libvirt, /var/log/swtpm) were missing on installed systems; that's why libvirt
# didn't start. On Fedora rpm-ostree does this automatically; here it's done by hand: each
# folder becomes a tmpfiles.d line with its owner and mode, and systemd-tmpfiles creates the
# missing ones at boot. Paths that already have a tmpfiles.d line creating the folder (d, D, v,
# q, Q, C, L) and pacman's own folders are skipped. Lines that only fix permissions (z, Z; e.g.
# swtpm's /var/lib/swtpm-localca) don't create the folder, so they don't count.
#
# Usage: var-tmpfiles.sh <tmpfiles.d file to write>

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
