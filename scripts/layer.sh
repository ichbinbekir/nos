#!/usr/bin/env bash
# Applies a layer to the image: the shared image (core/), machines (machines/<machine>/), later
# desktops. In the layer folder (all optional):
#   packages.txt  packages to install (one per line, anything after # is a comment)
#   aur.txt       AUR packages (same format); built in the aur-builder stage (aur.sh) and
#                 installed from /aur. For now only in the shared image (core/Containerfile mounts /aur).
#   system_files/ files copied to / as-is
#   services.txt  services to enable (same format)
#   setup.sh      tasks that don't fit in the lists; runs last
#
# Usage: layer.sh <layer folder> <name>
# <name> goes into the name of the tmpfiles.d file listing /var folders: nos-var-<name>.conf.

set -xeuo pipefail

dir="${1:?no layer folder given}"
name="${2:?no layer name given}"
[[ -d $dir ]] || { echo "Layer folder not found: $dir" >&2; exit 1; }

# Strips comments and whitespace from the lines.
list() { [[ -f $1 ]] && sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' "$1" || true; }

# The package database is not refreshed here (no -y). For the shared image, core/Containerfile
# does it right before. For machine images it's deliberate: versions should match the database
# the shared image was installed from. In particular nvidia-open is built for the exact kernel
# version, so a newer database could bring a version that doesn't match the kernel. In CI the
# machine build runs right after the shared image.
mapfile -t packages < <(list "$dir/packages.txt")
if ((${#packages[@]})); then
  pacman -S --noconfirm --needed "${packages[@]}"
fi

if [[ -f $dir/aur.txt ]]; then
  [[ -d /aur ]] || { echo "AUR packages were not built (/aur missing)" >&2; exit 1; }
  find /aur -name '*.pkg.tar.zst' ! -name '*-debug-*' -print0 | xargs -0 pacman -U --noconfirm
fi

# After the packages, so settings that replace a package's own file (e.g. /etc/environment)
# aren't overwritten by package installation.
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

# pacman keeps the Arch Docker image's own configs and leaves new versions as .pacnew;
# they're not needed.
find /etc -name '*.pacnew' -delete

# The hardware database (hwdb.bin) is regenerated during package installation with the build
# time as its date; even with identical content the image layer changed daily and was
# downloaded again. Its date is pinned to the newest of its source files (hwdb.d).
touch -d "@$(stat -c %Y /usr/lib/udev/hwdb.d/* | sort -n | tail -n1)" /usr/lib/udev/hwdb.bin

# Have the folders packages put under /var created at boot (see var-tmpfiles.sh).
bash "$(dirname "$0")/var-tmpfiles.sh" "/usr/lib/tmpfiles.d/nos-var-$name.conf"
