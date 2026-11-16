#!/usr/bin/env bash
# Source: bootcrew/mono shared/build.sh (Apache-2.0, see LICENSE).
# Changes:
# - A released version (vX.Y.Z tag) is built instead of the main branch; main can break at
#   any time. If BOOTC_VERSION is given, that version; otherwise the latest.
# - Built without SELinux support. Since 1.17 bootc requires libselinux by default; it isn't
#   in Arch's official repos and Arch doesn't use SELinux.
#   The options are taken from the example in bootc's Makefile.
# - The build folder and cargo cache are deleted at the end (below).

set -xeuo pipefail

git clone "https://github.com/bootc-dev/bootc.git" .
version="${BOOTC_VERSION:-$(git tag --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)}"
git checkout "$version"

make bin install-all DESTDIR=/output \
  CARGO_OPTIONS='--no-default-features --features "install-to-disk pre-6.15"'

# Keep build leftovers (target/, a few GB) out of this step's image layer: podman wrote them
# once more while committing the layer and the build machine's disk filled up
# ("no space left on device", Nov 2). The next stage only takes /output.
cd /
rm -rf /home/build /root/.cargo
