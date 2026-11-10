#!/usr/bin/bash

# Replace Fedora's libinput with a snapshot of upstream main from the
# rain1094/libinput-tishy COPR (packaging: ~/dev/libinput-rpm, branch tishy).
#
# Upstream main has the AttrTouchpadHysteresis quirk, which keeps the
# Framework 13 Pro's PixArt 093A:1343 haptic touchpad from switching
# hysteresis on and swallowing sub-0.25 mm cursor motion. No release has it
# yet. Once a Fedora libinput release includes it, the check at the end of
# this script fails the build: drop this script and the COPR then.

set -eoux pipefail

echo "::group::Executing install-libinput-tishy"
trap 'echo "::endgroup::"' EXIT

copr_repo=rain1094/libinput-tishy
copr_repo_id="copr:copr.fedorainfracloud.org:${copr_repo/\//:}"

dnf5 -y copr enable "$copr_repo"

# Upgrade only the libinput packages the base image already has, and only from
# the COPR, so nothing else gets pulled in from it.
mapfile -t installed < <(rpm -qa --qf '%{NAME}\n' 'libinput*' | sort -u)
dnf5 -y upgrade --repo="$copr_repo_id" "${installed[@]}"

# Disable the COPR again so it doesn't bleed into the live system's update
# path; updated packages are baked into each new image build.
dnf5 -y copr disable "$copr_repo"

# Fail the build loudly if the COPR build didn't land, e.g. because Fedora
# shipped a newer libinput than the COPR's. If that release has the quirk,
# drop this script; otherwise rebuild the COPR from a newer snapshot.
for pkg in "${installed[@]}"; do
    release=$(rpm -q --qf '%{RELEASE}' "$pkg")
    if [[ "$release" != *tishy* ]]; then
        echo "error: $pkg is $release, expected a .tishy. build from $copr_repo" >&2
        exit 1
    fi
done
