#!/usr/bin/env bash

set -ouex pipefail

#### Variables

echo "Installing Google Chrome"

mkdir -p /var/opt

cat << EOF > /etc/yum.repos.d/google-chrome.repo
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF

# Import signing key
rpm --import https://dl.google.com/linux/linux_signing_key.pub

# Touch the file which prevents the cron job from being installed
touch /etc/default/google-chrome

# Install packages
dnf5 -y install google-chrome-stable

# Remove the cron job
rm /etc/cron.daily/google-chrome

# Remove the repo file since updates are shipped with new images
rm /etc/yum.repos.d/google-chrome.repo

## Next, move google-chrome over to /usr/lib
mv /var/opt/google /usr/lib/google

# Register path symlink
# We do this via tmpfiles.d so that it is created by the live system.
cat >/usr/lib/tmpfiles.d/google-chrome.conf <<EOF
L  /opt/google  -  -  -  -  /usr/lib/google
EOF
