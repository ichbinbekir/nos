#!/usr/bin/env bash
# AUR paketlerini derleyip /output'a koyar. Bu betik ayrı bir build aşamasında
# çalışır; derleme araçları ve "build" kullanıcısı son imaja girmez.

set -xeuo pipefail

AUR_PACKAGES=(
  helium-browser-bin # Tarayıcı
  espanso # Metin kısaltmaları (ör. ":date" → tarih). Kaynaktan, sadece Wayland sürümü (aşağıda). Hazır Debian paketi (espanso-wayland-bin) Arch'ın wxWidgets'ıyla uyumsuzdu, açılışta çöküyordu
  zapret-git # DPI engelini aşma (bol-van/zapret). Ayarı /etc/zapret, bkz. README "Engelli siteler"
  cloudflare-warp-bin # Cloudflare WARP (ücretsiz VPN, hesap gerekmiyor): warp-cli + menüde "Cloudflare One Client". Servisi (warp-svc) açık gelir, VPN bağlanana kadar bağlanmaz; bkz. README
)

pacman -Syu --noconfirm --needed base-devel git

# makepkg root olarak çalışmaz. -s ile bağımlılıkları kurabilmesi için
# build kullanıcısına şifresiz sudo verilir (sadece bu aşamada).
useradd -m build
echo 'build ALL=(ALL) NOPASSWD: ALL' >/etc/sudoers.d/build
install -d -o build /output

for pkg in "${AUR_PACKAGES[@]}"; do
  runuser -u build -- git clone --depth 1 "https://aur.archlinux.org/${pkg}.git" "/home/build/${pkg}"
  cd "/home/build/${pkg}"

  # Kaynak dosyaların imzasını doğrulamak için PKGBUILD'deki PGP anahtarları alınır.
  for key in $(sed -n 's/^\s*validpgpkeys = //p' .SRCINFO); do
    runuser -u build -- gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys "${key}" ||
      runuser -u build -- gpg --keyserver hkps://keys.openpgp.org --recv-keys "${key}"
  done

  # Paketin tarihi her build'de "şimdi" olmasın: makepkg dosya tarihlerini ve paketin build
  # tarihini SOURCE_DATE_EPOCH'tan alıyor, chunkah da katmandaki tarihleri buna göre
  # sabitliyor. Tarih her gün değişince içerik aynı olsa da katman değişiyor ve her
  # güncellemede yeniden iniyordu (Helium ~180 MB/gün). AUR tarifinin son değişiklik
  # tarihi kullanılır; tarif güncellenince değişir.
  epoch=$(runuser -u build -- git -C "/home/build/${pkg}" log -1 --format=%ct)

  makepkg_args=()
  case "${pkg}" in
    espanso)
      # Tarif X11 ve Wayland sürümlerini ayrı ayrı derleyip testleri de derliyor (Rust, her
      # biri birkaç dakika). Sadece Wayland sürümü derlenir: X11'in derleme satırları ve
      # paket listesindeki adı silinir (makepkg'ın --pkg seçeneği artık yok), testler
      # atlanır. Tarif değişip satırlar bulunamazsa build durur.
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
