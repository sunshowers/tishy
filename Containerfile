ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-43}"

FROM ghcr.io/ublue-os/bazzite:latest AS tishy-base

ARG IMAGE_NAME="${IMAGE_NAME:-tishy}"
ARG IMAGE_VENDOR="${IMAGE_VENDOR:-sunshowers}"
ARG IMAGE_FLAVOR="${IMAGE_FLAVOR:-main}"
ARG IMAGE_BRANCH="${IMAGE_BRANCH:-main}"
ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-bazzite}"
ARG FEDORA_MAJOR_VERSION

## Copy system files over
COPY system_files /

## Add base packages

RUN --mount=type=cache,dst=/var/cache/rpm-ostree \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    dnf5 -y copr enable -y bazzite-org/bazzite && \
    dnf5 -y swap '*openh264*' noopenh264 && \
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
        powertop \
        ripgrep \
        strace \
        yakuake \
        zsh && \
    cat /tmp/flatpak_install >> /usr/share/ublue-os/bazzite/flatpak/install && \
    /tmp/install-1password.sh && \
    /tmp/install-chrome.sh && \
    /tmp/cleanup.sh && \
    ostree container commit

## Install other packages
## XXX: probably should combine everything into one layer

FROM tishy-base AS tishy
ARG FEDORA_MAJOR_VERSION

## Install other new packages
COPY system_files /
RUN --mount=type=cache,dst=/var/cache/rpm-ostree \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    /tmp/install-brave.sh && \
    curl -Lo /etc/yum.repos.d/_copr_wezfurlong-wezterm-nightly.repo https://copr.fedorainfracloud.org/coprs/wezfurlong/wezterm-nightly/repo/fedora-"${FEDORA_MAJOR_VERSION}"/wezfurlong-wezterm-nightly-"${FEDORA_MAJOR_VERSION}".repo && \
    curl -fsSLo "/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:scottames:ghostty.repo" https://copr.fedorainfracloud.org/coprs/scottames/ghostty/repo/fedora-"${FEDORA_MAJOR_VERSION}"/scottames-ghostty-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
    dnf5 -y install \
        brave-browser \
        ghostty \
        virt-install \
        virt-manager \
        virt-viewer \
        wezterm && \
    sed -i '/<entry name="launchers" type="StringList">/,/<\/entry>/ s/<default>[^<]*<\/default>/<default>applications:org.gnome.Prompt.desktop,preferred:\/\/browser,preferred:\/\/filemanager,applications:code.desktop,applications:steam.desktop<\/default>/' /usr/share/plasma/plasmoids/org.kde.plasma.taskmanager/contents/config/main.xml && \
    KERNEL_FLAVOR=bazzite /tmp/build-initramfs && \
    /tmp/cleanup.sh && \
    install -d -m 0755 /nix && \
    ostree container commit
