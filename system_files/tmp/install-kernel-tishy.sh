#!/usr/bin/bash

# Swap the stock kernel with custom kernel-tishy RPMs from /rpms/kernel.
# Based on Bazzite's install-kernel script.

set -eoux pipefail

echo "::group::Executing install-kernel-tishy"
trap 'echo "::endgroup::"' EXIT

# Create shims to bypass kernel install triggering dracut/rpm-ostree.
# These hooks would fail during container builds; we rebuild the
# initramfs separately in the Containerfile.
pushd /usr/lib/kernel/install.d
mv 05-rpmostree.install 05-rpmostree.install.bak
mv 50-dracut.install 50-dracut.install.bak
printf '%s\n' '#!/bin/sh' 'exit 0' > 05-rpmostree.install
printf '%s\n' '#!/bin/sh' 'exit 0' > 50-dracut.install
chmod +x 05-rpmostree.install 50-dracut.install
popd

# Clear existing kernel versionlock from the base image. Without this,
# dnf5 refuses to install our kernel because the base image locked the
# stock kernel version.
dnf5 versionlock clear

# Remove the stock kernel packages.
dnf5 -y remove --no-autoremove \
    kernel \
    kernel-core \
    kernel-modules \
    kernel-modules-core \
    kernel-modules-extra \
    kernel-tools \
    kernel-tools-libs

# Install our custom kernel RPMs.
pkgs=(
    kernel
    kernel-core
    kernel-modules
    kernel-modules-core
    kernel-modules-extra
    kernel-devel
    kernel-devel-matched
    kernel-tools
    kernel-tools-libs
    kernel-common
)

PKG_PAT=()
for pkg in "${pkgs[@]}"; do
    # Glob for kernel RPMs starting with version 6.
    PKG_PAT+=("/rpms/kernel/${pkg}-6"*)
done

dnf5 -y install "${PKG_PAT[@]}"

# Lock kernel version to prevent the stock kernel from being pulled
# back in during future dnf operations.
dnf5 versionlock add "${pkgs[@]}"

# Restore original kernel install hooks.
pushd /usr/lib/kernel/install.d
mv -f 05-rpmostree.install.bak 05-rpmostree.install
mv -f 50-dracut.install.bak 50-dracut.install
popd
