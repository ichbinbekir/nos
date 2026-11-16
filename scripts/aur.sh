#!/usr/bin/env bash
# Builds the AUR packages listed in a layer's aur.txt and puts them in /output. This script runs
# in a separate build stage; the build tools and the "build" user don't reach the final image.
#
# Usage: aur.sh <aur.txt>

set -xeuo pipefail

mapfile -t AUR_PACKAGES < <(sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' "${1:?no AUR list given}")

pacman -Syu --noconfirm --needed base-devel git

# makepkg doesn't run as root. So it can install dependencies with -s, the build user gets
# passwordless sudo (only in this stage).
useradd -m build
echo 'build ALL=(ALL) NOPASSWD: ALL' >/etc/sudoers.d/build
install -d -o build /output

for pkg in "${AUR_PACKAGES[@]}"; do
  runuser -u build -- git clone --depth 1 "https://aur.archlinux.org/${pkg}.git" "/home/build/${pkg}"
  cd "/home/build/${pkg}"

  # Fetch the PGP keys listed in the PKGBUILD to verify the source file signatures.
  for key in $(sed -n 's/^\s*validpgpkeys = //p' .SRCINFO); do
    runuser -u build -- gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys "${key}" ||
      runuser -u build -- gpg --keyserver hkps://keys.openpgp.org --recv-keys "${key}"
  done

  # Don't let the package date be "now" on every build: makepkg takes file dates and the
  # package build date from SOURCE_DATE_EPOCH, and chunkah pins layer dates to it. When the
  # date changed daily, the layer changed even with identical content and was downloaded
  # again on every update (Helium ~180 MB/day). The AUR recipe's last commit date is used;
  # it changes when the recipe is updated.
  epoch=$(runuser -u build -- git -C "/home/build/${pkg}" log -1 --format=%ct)

  makepkg_args=()
  case "${pkg}" in
    espanso)
      # The recipe builds the X11 and Wayland variants separately and also builds the tests
      # (Rust, a few minutes each). Only the Wayland variant is built: the X11 build lines and
      # its name in the package list are deleted (makepkg no longer has --pkg) and tests are
      # skipped. If the recipe changes and the lines aren't found, the build stops.
      runuser -u build -- sed -i \
        -e '/export CARGO_TARGET_DIR=target-x11/,/--package espanso/d' \
        -e '/^pkgname=(/,/^)/{/espanso-x11/d}' PKGBUILD
      if grep -q 'CARGO_TARGET_DIR=target-x11' PKGBUILD; then exit 1; fi
      grep -q 'CARGO_TARGET_DIR=target-wayland' PKGBUILD
      [[ "$(runuser -u build -- bash -c 'source PKGBUILD && echo "${pkgname[*]}"')" == espanso-wayland ]]
      makepkg_args=(--nocheck)
      ;;
  esac
  runuser -u build -- env PKGDEST=/output SOURCE_DATE_EPOCH="${epoch}" makepkg -s --noconfirm "${makepkg_args[@]}"
done
