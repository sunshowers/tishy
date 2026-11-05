ARG SOURCE_IMAGE=bazzite

FROM ghcr.io/ublue-os/${SOURCE_IMAGE}:latest AS tishy-base

ARG IMAGE_NAME="${IMAGE_NAME:-tishy}"
ARG IMAGE_VENDOR="${IMAGE_VENDOR:-sunshowers}"
ARG IMAGE_FLAVOR="${IMAGE_FLAVOR:-main}"
ARG IMAGE_BRANCH="${IMAGE_BRANCH:-main}"
ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-bazzite}"

## Copy system files over
COPY system_files /

## Add base packages

RUN --mount=type=cache,dst=/var/cache/rpm-ostree \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    dnf5 -y copr enable -y bazzite-org/bazzite && \
    dnf5 -y install \
        bpftrace \
        code \
        corectrl \
        direnv \
        evtest \
        fd-find \
        firefox \
        libguestfs-tools \
        perf \
        podman-compose \
        powertop \
        ripgrep \
        strace \
        yakuake \
        zsh && \
    /tmp/install-1password.sh && \
    /tmp/install-chrome.sh && \
    /tmp/cleanup.sh

## Install other packages
## XXX: probably should combine everything into one layer

FROM tishy-base AS tishy

## Install other new packages
COPY system_files /
RUN --mount=type=cache,dst=/var/cache/rpm-ostree \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    /tmp/install-brave.sh && \
    dnf5 -y copr enable wezfurlong/wezterm-nightly && \
    dnf5 -y copr enable scottames/ghostty && \
    dnf5 -y install \
        brave-browser \
        ghostty \
        guestfs-tools \
        libvirt-daemon-kvm \
        virt-install \
        virt-manager \
        virt-viewer \
        virtiofsd \
        wezterm && \
    /tmp/install-niri-dms.sh && \
    /tmp/install-fonts.sh && \
    KERNEL_FLAVOR=bazzite /tmp/build-initramfs && \
    /tmp/cleanup.sh && \
    install -d -m 0755 /nix

# Validate the image the way Bazzite does (bootc's replacement for the
# deprecated `ostree container commit`, which fails outright on Fedora 45
# bases). A tmpfs /run and no network keep build-time state out of the check.
RUN --mount=type=tmpfs,target=/run \
    --network=none \
    bootc container lint
