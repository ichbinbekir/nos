# Build betikleri ve sistem dosyaları ayrı bir aşamada tutulur, son imaja kopyalanmaz.
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

FROM docker.io/archlinux/archlinux:latest AS base

# bootc Arch depolarında yok, kaynak koddan derlenir (bootcrew/mono).
FROM base AS bootc-builder
RUN pacman -Syu --noconfirm make git rust go-md2man ostree glibc pkgconf
WORKDIR /home/build
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    bash /ctx/bootc/build-bootc.sh

# AUR paketleri ayrı bir aşamada derlenir; makepkg root olarak çalışmadığı için
# bu aşamada ayrı bir kullanıcı açılır. Son imaja sadece paket dosyaları geçer.
FROM base AS aur-builder
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    bash /ctx/aur.sh

FROM base AS system

COPY --from=bootc-builder /output /

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

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    sed -i 's|^HOME=.*|HOME=/var/home|' "/etc/default/useradd" && \
    bash /ctx/bootc/bootc-rootfs.sh

LABEL containers.bootc 1

RUN bootc container lint
