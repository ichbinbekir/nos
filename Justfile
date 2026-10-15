image_name := env("IMAGE_NAME", "nos")
tag := env("IMAGE_TAG", "latest")
filesystem := env("BUILD_FILESYSTEM", "btrfs")

[private]
default:
    @just --list

# İmajı build eder
build $image_name=image_name $tag=tag:
    podman build --pull=newer --file Containerfile --tag "${image_name}:${tag}" .

# İmajı, güncellemelerde sadece değişen kısımlar indirilecek şekilde katmanlara böler (ublue-os/image-template, Apache-2.0)
rechunk $image_name=image_name $tag=tag:
    #!/usr/bin/env bash
    set -xeuo pipefail

    CHUNKAH_CONFIG_FILE="$(mktemp)"
    CHUNKAH_OUTPUT_DIR="$(mktemp -d ./"${image_name}"_chunkah_XXXXXX)"
    trap 'rm -f "${CHUNKAH_CONFIG_FILE}"; rm -rf "${CHUNKAH_OUTPUT_DIR}"' EXIT
    podman inspect "${image_name}:${tag}" > "${CHUNKAH_CONFIG_FILE}"

    podman run --rm \
      --mount=type=image,src="${image_name}:${tag}",target=/chunkah \
      -v "${CHUNKAH_CONFIG_FILE}:/chunkah-config.json:ro,Z" \
      -v "${CHUNKAH_OUTPUT_DIR}:/run/out:Z" \
      quay.io/coreos/chunkah:latest \
      build \
      --verbose \
      --compressed \
      --max-layers 128 \
      --prune /sysroot/ \
      --label ostree.commit- --label ostree.final-diffid- \
      --config /chunkah-config.json \
      --output oci:/run/out/chunked

    CHUNKED_IMAGE="$(podman pull "oci:${CHUNKAH_OUTPUT_DIR}/chunked")"
    podman tag "${CHUNKED_IMAGE}" "${image_name}:${tag}"

# İmajdan sanal makine için ham disk imajı üretir (bootcrew/mono). Root podman ister; imaj root depolamasında olmalı.
disk-image image=(image_name + ":" + tag) $filesystem=filesystem:
    #!/usr/bin/env bash
    set -xeuo pipefail

    mkdir -p output
    rm -f output/disk.raw
    fallocate -l 20G output/disk.raw

    podman run --rm --privileged --pid=host \
      --security-opt label=type:unconfined_t \
      -v /var/lib/containers:/var/lib/containers \
      -v /etc/containers:/etc/containers \
      -v /dev:/dev \
      -v "${PWD}/output:/data" \
      "{{ image }}" \
      bootc install to-disk \
        --composefs-backend \
        --bootloader systemd \
        --filesystem "${filesystem}" \
        --via-loopback /data/disk.raw \
        --wipe

# Ham disk imajını sıkıştırılmış qcow2'ye çevirir
qcow2:
    qemu-img convert -c -p -f raw -O qcow2 output/disk.raw output/disk.qcow2
