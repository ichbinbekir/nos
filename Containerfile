# bootc Arch depolarında yok. Kaynak koddan derlenmiş hali ayrı bir imajda duruyor
# (build_files/bootc/Containerfile, .github/workflows/build-bootc.yml); burada sadece
# dosyaları kopyalanır.
ARG BOOTC_IMAGE=ghcr.io/ichbinbekir/nos-bootc:latest

# Build betikleri ve sistem dosyaları ayrı bir aşamada tutulur, son imaja kopyalanmaz.
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

FROM ${BOOTC_IMAGE} AS bootc

FROM docker.io/archlinux/archlinux:latest AS base

# AUR paketleri ayrı bir aşamada derlenir; makepkg root olarak çalışmadığı için
# bu aşamada ayrı bir kullanıcı açılır. Son imaja sadece paket dosyaları geçer.
FROM base AS aur-builder
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    bash /ctx/aur.sh

FROM base AS system

COPY --from=bootc / /

# pacman'in /var altındaki her şeyi /usr/lib/sysimage'a taşınır: bootc'de /var imajın
# parçası olmadığı için paket veritabanı /usr ile birlikte güncellenmeli (bootcrew/mono).
RUN grep "= */var" /etc/pacman.conf | sed "/= *\/var/s/.*=// ; s/ //" | xargs -n1 sh -c 'mkdir -p "/usr/lib/sysimage/$(dirname $(echo $1 | sed "s@/var/@@"))" && mv -v "$1" "/usr/lib/sysimage/$(echo "$1" | sed "s@/var/@@")"' '' && \
    sed -i -e "/= *\/var/ s/^#//" -e "s@= */var@= /usr/lib/sysimage@g" -e "/DownloadUser/d" /etc/pacman.conf

# /run ve /tmp tmpfs olarak bağlanır: paket kurulumu sırasında oluşan çalışma
# zamanı dosyaları imaja girmez (bootc container lint).
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,from=aur-builder,source=/output,target=/aur \
    --mount=type=cache,dst=/usr/lib/sysimage/cache/pacman/pkg \
    --mount=type=tmpfs,dst=/run \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build.sh

RUN --mount=type=tmpfs,dst=/tmp --mount=type=tmpfs,dst=/root \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    bash /ctx/bootc/initramfs.sh

# Sürüm (build tarihi) os-release'e initramfs üretildikten SONRA eklenir. bootc açılış
# menüsündeki adı buradan alıyor ("nos 20261017"); dracut ise os-release'i initrd'ye
# kopyalıyor, tarih daha önce yazılırsa ~140 MB'lık initrd her gün değişir.
RUN echo "VERSION_ID=$(date -u +%Y%m%d)" >>/usr/lib/os-release

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    sed -i 's|^HOME=.*|HOME=/var/home|' "/etc/default/useradd" && \
    bash /ctx/bootc/bootc-rootfs.sh

LABEL containers.bootc 1

RUN bootc container lint
