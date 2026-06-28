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
# (greetd, dms-greeter) and ghostty, which tishy already installs. adw-gtk3 is
# the base GTK3 theme that DMS's matugen GTK theming layers onto (it sets
# gtk-theme to adw-gtk3-dark); without it GTK3 apps fall back to light Adwaita.
dnf5 -y install \
    acl \
    adw-gtk3 \
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

# niri drives screencasting through GNOME's Mutter ScreenCast D-Bus interface,
# so screen sharing (e.g. picking a window in a browser) needs the GNOME
# xdg-desktop-portal backend. tishy's KDE base only ships the gtk and kde
# backends, and niri-portals.conf (shipped by the niri package) already prefers
# "gnome", so we just need the backend present. It is only selected under niri;
# the KDE session keeps using the kde backend.
dnf5 -y install xdg-desktop-portal-gnome

# The KDE Xwayland video bridge autostarts in every session, but under niri it
# is non-functional (it relies on the Plasma screencast portal) and shows up as
# a black fullscreen window. Exclude it from the niri session only; it stays
# active under KDE, where X11 apps still use it.
bridge_autostart="/etc/xdg/autostart/org.kde.xwaylandvideobridge.desktop"
if [[ -f "$bridge_autostart" ]] && ! grep -q '^NotShowIn=' "$bridge_autostart"; then
    printf 'NotShowIn=niri;\n' >> "$bridge_autostart"
fi

# DankCalendar ships a user service that runs the dcal tray daemon
# (`dcal run --session --hidden`). Enable it globally so the calendar is
# available in the tray on login. It binds to graphical-session.target, so it
# runs under both DMS/niri and KDE; accounts are configured later from dcal's
# own UI.
systemctl --global enable dcal.service

# /etc/skel only seeds *new* home directories, so enable a user service that
# copies the niri config into existing accounts on first graphical login. It is
# non-destructive and short-circuits under KDE; see the script for details.
chmod +x /usr/local/libexec/tishy-niri-seed
systemctl --global enable tishy-niri-seed.service
