#!/usr/bin/env bash
# Kaynak: bootcrew/mono shared/build.sh (Apache-2.0, bkz. LICENSE).
# Değişiklikler:
# - main dalı yerine yayınlanmış bir sürüm (vX.Y.Z etiketi) derleniyor; main her an
#   bozulabiliyor. BOOTC_VERSION verilirse o sürüm, verilmezse en sonuncusu.
# - SELinux desteği kapalı derleniyor. bootc 1.17'den beri varsayılan olarak
#   libselinux istiyor; Arch'ın resmi depolarında yok ve Arch SELinux kullanmıyor.
#   Seçenekler bootc Makefile'ındaki örnekten alındı.

set -xeuo pipefail

git clone "https://github.com/bootc-dev/bootc.git" .
version="${BOOTC_VERSION:-$(git tag --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)}"
git checkout "$version"

make bin install-all DESTDIR=/output \
  CARGO_OPTIONS='--no-default-features --features "install-to-disk pre-6.15"'
