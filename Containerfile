ARG FEDORA_MAJOR_VERSION="${FEDORA_VERSION:-40}"
FROM ghcr.io/ublue-os/bazzite-nvidia:latest AS sefirot-base

ARG IMAGE_NAME="${MY_IMAGE_NAME:-sefirot-nvidia}"
ARG IMAGE_VENDOR="${IMAGE_VENDOR:-butterflysky}"
ARG IMAGE_FLAVOR="${IMAGE_FLAVOR:-nvidia}"
ARG IMAGE_BRANCH="${IMAGE_BRANCH:-main}"
ARG BASE_IMAGE_NAME="${SOURCE_IMAGE:-bazzite-nvidia}"
ARG FEDORA_MAJOR_VERSION

## Copy system files over
COPY system_files /

## Add infrequently-updated packages

RUN \
  sed -i -e 's@enabled=0@enabled=1@g' \
    /etc/yum.repos.d/_copr_kylegospo-bazzite.repo \
    /etc/yum.repos.d/_copr_che-nerd-fonts.repo

RUN rpm-ostree install \
    bat \
    cfonts \
    cockpit-bridge \
    cockpit-kdump \
    cockpit-machines \
    cockpit-navigator \
    cockpit-networkmanager \
    cockpit-podman \
    cockpit-selinux \
    cockpit-storaged \
    cockpit-system \
    direnv \
    evtest \
    fd-find \
    firefox \
    libguestfs-tools \
    nerd-fonts \
    perf \
    powertop \
    ripgrep \
    strace \
    syncthing \
    virt-install \
    virt-manager \
    virt-viewer \
    zsh \
    zsh-syntax-highlighting

## Add flatpak packages
RUN cat /tmp/flatpak_install >> /usr/share/ublue-os/bazzite/flatpak/install

## Commit
RUN rm -rf /var/* && ostree container commit

FROM sefirot-base AS sefirot-1password

## Add 1password
COPY system_files /
RUN /tmp/install-1password.sh

## Commit
RUN rm -rf /var/* && ostree container commit

## Next: install system Chrome
FROM sefirot-1password AS sefirot-chrome
ARG FEDORA_MAJOR_VERSION

## Add system Chrome
COPY system_files /
RUN /tmp/install-chrome.sh

## Commit
RUN rm -rf /var/* && ostree container commit

FROM sefirot-chrome AS sefirot-nvidia
ARG FEDORA_MAJOR_VERSION

## Configure KDE & GNOME
#RUN sed -i '/<entry name="launchers" type="StringList">/,/<\/entry>/ s/<default>[^<]*<\/default>/<default>applications:org.gnome.Prompt.desktop,preferred:\/\/browser,preferred:\/\/filemanager,applications:code.desktop,applications:steam.desktop<\/default>/' /usr/share/plasma/plasmoids/org.kde.plasma.taskmanager/contents/config/main.xml && \
#    sed -i '/<entry name="favorites" type="StringList">/,/<\/entry>/ s/<default>[^<]*<\/default>/<default>org.gnome.Prompt.desktop,preferred:\/\/browser,org.kde.dolphin.desktop,code.desktop,steam.desktop<\/default>/' /usr/share/plasma/plasmoids/org.kde.plasma.kickoff/contents/config/main.xml

### 5. POST-MODIFICATIONS
## these commands leave the image in a clean state after local modifications
# Cleanup & Finalize
RUN \
    rm -rf /tmp/* /var/* && \
    ostree container commit
