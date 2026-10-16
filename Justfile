image_name := env("IMAGE_NAME", "nos")
tag := env("IMAGE_TAG", "latest")
filesystem := env("BUILD_FILESYSTEM", "btrfs")
bootc_image := env("BOOTC_IMAGE", "ghcr.io/ichbinbekir/nos-bootc:latest")

[private]
default:
    @just --list

# İmajı build eder (bootc, bootc_image imajından kopyalanır)
build $image_name=image_name $tag=tag $bootc_image=bootc_image:
    podman build --pull=newer --file Containerfile --build-arg BOOTC_IMAGE="${bootc_image}" --tag "${image_name}:${tag}" .

# bootc'yi derleyip sadece onu içeren küçük imajı build eder. version boşsa en son sürüm.
build-bootc $version="" $image_name="nos-bootc":
    podman build --pull=newer --file build_files/bootc/Containerfile --build-arg BOOTC_VERSION="${version}" --tag "${image_name}:latest" build_files/bootc

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

# Ham disk imajını sanal makine biçimine çevirir: qcow2 (QEMU/virt-manager) ya da vdi (VirtualBox)
convert format="vdi":
    #!/usr/bin/env bash
    set -xeuo pipefail
    case "{{ format }}" in
      qcow2) qemu-img convert -c -p -f raw -O qcow2 output/disk.raw output/disk.qcow2 ;;
      vdi) qemu-img convert -p -f raw -O vdi output/disk.raw output/disk.vdi ;;
      *) echo "Bilinmeyen biçim: {{ format }}" >&2; exit 1 ;;
    esac
