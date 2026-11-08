#!/usr/bin/bash

# Install the niri scrolling Wayland compositor and DankMaterialShell (DMS),
# based on https://github.com/irunatbullets/spacium.
#
# Unlike spacium, tishy keeps its existing KDE/sddm session: this script only
# *adds* niri as a selectable Wayland session and makes DMS available. It does
# not swap the display manager (no greetd) or disable the stock session, so the
# deck experience is left intact. Some defaults do change in every session,
# though: Dux Files handles "show in folder" requests (see below).
#
# Select "niri" from sddm to launch it; DMS is started as dms.service, pulled in
# by niri.service (see /usr/lib/systemd/user/niri.service.d/60-dms.conf), so it
# runs only under niri.

set -eoux pipefail

echo "::group::Executing install-niri-dms"
trap 'echo "::endgroup::"' EXIT

# COPRs that host niri, DMS, quickshell, and the DMS helper tools.
copr_repos=(
    irunatbullets/spacium-extras
    duxlabs/dms
    duxlabs/dux-repo
)

for repo in "${copr_repos[@]}"; do
    dnf5 -y copr enable "$repo"
done

# Package set drawn from spacium's build, minus the display-manager swap
# (greetd, dms-greeter) and ghostty, which tishy already installs. The
# adw-gtk3-theme package provides the adw-gtk3-dark GTK3 theme that DMS's matugen
# GTK theming layers onto (it sets gtk-theme to adw-gtk3-dark); without it GTK3
# apps fall back to light Adwaita. (Fedora ships this as adw-gtk3-theme; the bare
# adw-gtk3 name spacium uses does not resolve on our base.)
#
# DMS moved from the avengemedia COPRs to duxlabs, and its helper tools were
# renamed on the way (dankcalendar-git -> dux-calendar-git, danksearch ->
# dux-search, dgop -> dux-gop). Use the new names: Fedora itself also ships
# danksearch and dgop, so the old names could resolve to those instead.
# breakpad is gone from the new repo and quickshell no longer depends on it;
# cliphist now comes from Fedora.
dnf5 -y install \
    acl \
    adw-gtk3-theme \
    bluetui \
    cava \
    cliphist \
    dms \
    dux-calendar-git \
    dux-files \
    dux-gop \
    dux-search \
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

# Dux Files and Dolphin both ship D-Bus activation files claiming
# org.freedesktop.FileManager1, which answers "show in folder" requests from
# browsers and so on. With two claimants, which one the bus starts depends on
# load order, so drop Dolphin's and let Dux Files handle it in every session.
#
# Check that the Dux Files paths referenced elsewhere in the image exist, and
# use rm without -f: if either package renames one of these files, the build
# fails here rather than silently leaving a dangling default or two claimants.
dux_files_paths=(
    # Activation file that takes over FileManager1 once Dolphin's is gone.
    /usr/share/dbus-1/services/dev.duxlabs.files.FileManager1.service
    # Named by inode/directory in /usr/share/applications/niri-mimeapps.list.
    /usr/share/applications/dev.duxlabs.files.desktop
    # Named by FileChooser= in /etc/xdg-desktop-portal/niri-portals.conf.
    /usr/share/xdg-desktop-portal/portals/dfiles.portal
)
for path in "${dux_files_paths[@]}"; do
    if [[ ! -f "$path" ]]; then
        echo "dux-files no longer ships $path; update the image config that refers to it" >&2
        exit 1
    fi
done
rm /usr/share/dbus-1/services/org.kde.dolphin.FileManager1.service

# /etc/skel only seeds *new* home directories, so enable a user service that
# copies the niri, DMS, and Ghostty config into existing accounts at graphical
# login. It only ever creates paths that don't exist yet, so it never touches
# existing config, under niri or KDE; see the script for details.
chmod +x /usr/local/libexec/tishy-niri-seed
systemctl --global enable tishy-niri-seed.service

# uresourced (pulled in by plasma-workspace) has a user half whose only job is
# "app boost": focus tracking via an xattr only GNOME Shell sets, plus a CPU/IO
# weight bump for apps playing audio. It sends a SetUnitProperties call for
# every PipeWire node event, without checking whether anything changed. On
# 2026-11-05 a burst of these on dms.service kept the user manager busy enough
# that no new scope could start, so nothing launched from DMS or niri.
#
# Masking it costs little. The system daemon then gives user@.service no
# MemoryMin of its own, but user-N.slice keeps its protection, which
# memory_recursiveprot (set on Fedora's cgroup2 mount) passes down. The
# session.slice drop-in and the cgroupify drop-ins for browsers don't depend
# on the user daemon.
systemctl --global mask uresourced.service
