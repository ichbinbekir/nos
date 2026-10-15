#!/usr/bin/env bash
# AUR paketlerini derleyip /output'a koyar. Bu betik ayrı bir build aşamasında
# çalışır; derleme araçları ve "build" kullanıcısı son imaja girmez.

set -xeuo pipefail

AUR_PACKAGES=(
  helium-browser-bin # Tarayıcı
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

  runuser -u build -- env PKGDEST=/output makepkg -s --noconfirm
done
