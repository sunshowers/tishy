#!/usr/bin/bash

# Install the niri scrolling Wayland compositor and DankMaterialShell (DMS),
# based on https://github.com/irunatbullets/spacium.
#
# Unlike spacium, tishy keeps its existing KDE/sddm session: this script only
# *adds* niri as a selectable Wayland session and makes DMS available. It does
# not swap the display manager (no greetd) or disable the stock session, so the
# deck experience is left intact. Select "niri" from sddm to launch it; DMS is
# started from niri's own config (e.g. `spawn-at-startup "dms" "run"`).

set -eoux pipefail

echo "::group::Executing install-niri-dms"
trap 'echo "::endgroup::"' EXIT

# COPRs that host niri, DMS, quickshell, and the DMS helper tools.
copr_repos=(
    irunatbullets/spacium-extras
    avengemedia/dms
    avengemedia/danklinux
)

for repo in "${copr_repos[@]}"; do
    dnf5 -y copr enable "$repo"
done

# Package set drawn from spacium's build, minus the display-manager swap
# (greetd, dms-greeter) and ghostty, which tishy already installs.
dnf5 -y install \
    acl \
    bluetui \
    breakpad \
    cava \
    cliphist \
    dankcalendar-git \
    danksearch \
    dgop \
    dms \
    material-symbols-fonts \
    matugen \
    niri \
    qt6-qt5compat \
    qt6-qtimageformats \
    qt6-qtmultimedia \
    qt6-qtsvg \
    quickshell-git \
    tmux \
    wl-clipboard \
    xwayland-satellite

# Disable the COPRs again so they don't bleed into the live system's update
# path; updated packages are baked into each new image build.
for repo in "${copr_repos[@]}"; do
    dnf5 -y copr disable "$repo"
done
