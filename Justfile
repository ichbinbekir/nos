image_name := env("IMAGE_NAME", "nos")
tag := env("IMAGE_TAG", "latest")
bootc_image := env("BOOTC_IMAGE", "ghcr.io/ichbinbekir/nos-bootc:latest")
# The shared image is not published; machine images are built on top of the locally built nos.
base_image := env("BASE_IMAGE", "localhost/nos:latest")

[private]
default:
    @just --list

# Build the image (bootc is copied from the bootc_image image)
build $image_name=image_name $tag=tag $bootc_image=bootc_image:
    podman build --pull=newer --file core/Containerfile --build-arg BOOTC_IMAGE="${bootc_image}" --tag "${image_name}:${tag}" .

# Build a machine image (nos-<machine>) on top of the shared image (machines/<machine>/)
build-machine machine $base_image=base_image $tag=tag:
    podman build --file machines/Containerfile --build-arg BASE_IMAGE="${base_image}" --build-arg MACHINE="{{ machine }}" --tag "nos-{{ machine }}:${tag}" .

# Compile bootc and build the small image containing only it. Empty version = latest release.
build-bootc $version="" $image_name="nos-bootc":
    podman build --pull=newer --file scripts/bootc/Containerfile --build-arg BOOTC_VERSION="${version}" --tag "${image_name}:latest" scripts/bootc

# Split the image into layers so updates only download the parts that changed (ublue-os/image-template, Apache-2.0)
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
