#!/usr/bin/env bash
# Kaynak: bootcrew/mono shared/build.sh (Apache-2.0, bkz. LICENSE). Değiştirilmedi.

set -xeuo pipefail

git clone "https://github.com/bootc-dev/bootc.git" .

make bin install-all DESTDIR=/output
