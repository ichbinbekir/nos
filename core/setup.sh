#!/usr/bin/env bash
# Shared-image tasks that don't fit in the lists. scripts/layer.sh calls this after installing
# packages, copying system_files and enabling services. Settings with fixed content are not
# here but plain files in system_files; only settings that must be generated or need a small
# change to a package's file live here.

set -xeuo pipefail

# distrobox 1.8.2.5 bug: it mounts read-only folders with "ro:rslave", podman rejects that
# ("incorrect volume format") and the box can't be created. The correct form is "ro,rslave"
# (fixed upstream, distrobox#2083; no fixed release yet). It shows up because a line in crun's
# podman info output contains "runc", so distrobox picks its runc code path. Once a fixed
# release lands the line is not found and this step is skipped automatically.
if grep -qF ':ro${rslave}"' /usr/bin/distrobox-create; then
  sed -i 's|:ro\${rslave}"|:ro,rslave"|' /usr/bin/distrobox-create
  grep -qF ':ro,rslave"' /usr/bin/distrobox-create
fi

# On Wayland espanso reads the keyboard from /dev/input; its own install script grants this
# capability. It is set explicitly here (in case the package script changes) and logged (the
# capability survives in image layers; kwin_wayland's capability arrives the same way).
setcap cap_dac_override+p /usr/bin/espanso
getcap /usr/bin/espanso

# git doesn't preserve file permissions; sudo won't read the file without this mode.
chmod 0440 /etc/sudoers.d/10-wheel

# Locales. Which one is used is chosen during installation.
sed -i -e 's/^#\(en_US.UTF-8 UTF-8\)/\1/' -e 's/^#\(tr_TR.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen

# First boot: system_files/etc/machine-id is "uninitialized", so the system detects first boot;
# nos-firstboot asks the questions. systemd-firstboot, which does half the same job, is masked.
systemctl mask systemd-firstboot.service
systemctl set-default graphical.target

# Firewall (ufw): incoming connections denied by default, outgoing allowed.
# Only KDE Connect's ports are opened. ufw doesn't run during the build, so the rules are only
# written to files; with ENABLED=yes, ufw.service applies them at boot.
ufw default deny incoming
ufw default allow outgoing
ufw allow 1714:1764/tcp comment 'KDE Connect'
ufw allow 1714:1764/udp comment 'KDE Connect'
# VM network (libvirt's "default" NAT network, virbr0): with incoming denied, VMs couldn't get
# an IP (DHCP) and DNS from the host's dnsmasq; ufw also blocks forwarding by default, so they
# couldn't reach the internet. Only virbr0 is allowed.
ufw allow in on virbr0 comment 'libvirt: DHCP/DNS'
ufw route allow in on virbr0 comment 'libvirt: VM -> internet'
ufw route allow out on virbr0 comment 'libvirt: internet -> VM'
sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf

# System name (system_files/usr/lib/os-release): /etc/os-release must be a symlink to it;
# the Arch Docker image turns it into a regular file. Git and Windows don't carry symlinks
# reliably, so the link is created here.
ln -sf ../usr/lib/os-release /etc/os-release

# Autostart libvirt's ready-made "default" NAT network (definition shipped with the package)
# when the service starts; VMs reach the internet without extra setup (virsh net-autostart default).
ln -sf ../default.xml /etc/libvirt/qemu/networks/autostart/default.xml
