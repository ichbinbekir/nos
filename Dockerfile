FROM ghcr.io/ublue-os/base-nvidia:latest

RUN dnf5 -y install \
  microcode_ctl \
  fish \
  vim \
  git \
  && dnf5 clean all

RUN bootc container lint
