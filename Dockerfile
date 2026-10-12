FROM ghcr.io/ublue-os/base-nvidia:latest

# /var/cache, /var/log ve /tmp mount edildiği için dnf önbelleği ve logları imaja girmez.
# Mount edilmeyen /run/dnf ve /var/lib/dnf/repos ise elle temizlenir.
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    dnf5 -y install \
      microcode_ctl \
      fish \
      vim \
      git \
    && rm -rf /run/dnf /var/lib/dnf/repos

RUN bootc container lint
