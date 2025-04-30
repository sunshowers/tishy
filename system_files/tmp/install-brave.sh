#!/usr/bin/env bash

set -ouex pipefail

# Prepare staging directory
mkdir -p /var/opt # -p just in case it exists

# Setup repo
curl -fsSLo /etc/yum.repos.d/brave-browser.repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc

# Install
rpm-ostree install brave-browser

# Clean up the yum repo (updates are baked into new images)
rm /etc/yum.repos.d/brave-browser.repo -f

mv /var/opt/brave.com /usr/lib/brave.com # move this over here
rm /usr/bin/brave-browser /usr/bin/brave-browser-stable
ln -s /opt/brave.com/brave/brave-browser /usr/bin/brave-browser
ln -s /opt/brave.com/brave/brave-browser /usr/bin/brave-browser-stable

# Register path symlink
# We do this via tmpfiles.d so that it is created by the live system.
cat >/usr/lib/tmpfiles.d/brave-browser.conf <<EOF
L  /opt/brave.com  -  -  -  -  /usr/lib/brave.com
EOF
