#!/usr/bin/bash

# Replace Fedora's libinput with the patched build from the rain1094/libinput-tishy
# COPR (packaging: ~/dev/libinput-rpm, branch tishy; patches: ~/dev/libinput,
# branch tishy/1.32.0).
#
# Patches carried:
# - Keep touchpad hysteresis disabled once a plugin disables it. Stock libinput
#   only clears hysteresis.enabled, and on touchpads without axis fuzz (like the
#   Framework 13 Pro's PixArt 093A:1343 haptic pad) wobble detection turns it
#   back on at runtime, swallowing sub-0.25 mm cursor motion. The plugin that
#   requests this lives in /etc/libinput/plugins/.

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

# Fail the build loudly if the patched build didn't land, e.g. because Fedora
# shipped a newer libinput than the COPR's. Rebase the patches when that
# happens rather than silently dropping them.
for pkg in "${installed[@]}"; do
    release=$(rpm -q --qf '%{RELEASE}' "$pkg")
    if [[ "$release" != *tishy* ]]; then
        echo "error: $pkg is $release, expected a .tishy. build from $copr_repo" >&2
        exit 1
    fi
done
