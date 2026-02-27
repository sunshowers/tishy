# kernel-tishy architecture

## Two-repo layout

```
kernel-tishy (~/dev/kernel-tishy)          tishy (~/dev/tishy)
├── kernel.spec                            ├── Containerfile.deck
├── patch-5-hdmi-frl.patch                 ├── system_files/tmp/install-kernel-tishy.sh
├── build.sh                               └── .github/workflows/build.yml
├── oci.sh                                      (push-ghcr-deck job)
├── Dockerfile
└── .github/workflows/build.yml
```

**kernel-tishy** builds a Linux 6.19.x kernel with HDMI FRL patches as RPMs, packages them into an OCI container, and pushes to `ghcr.io/sunshowers/kernel-tishy`.

**tishy** (this repo) builds `tishy-deck` by starting from `bazzite-deck:latest`, swapping the kernel with RPMs from the kernel-tishy container, and pushing to `ghcr.io/sunshowers/tishy-deck`.

## Kernel build pipeline

```
linux-6.19.x.tar.xz (from cdn.kernel.org)
    ↓
kernel.spec applies patch-5-hdmi-frl.patch
    ↓
rpmbuild --with bazzite --with ubsb (in Fedora container via Podman)
    ↓
kernel RPMs (kernel-core, kernel-modules, kernel-devel, etc.)
    ↓
oci.sh packages RPMs into scratch OCI image
    ↓
ghcr.io/sunshowers/kernel-tishy:main-f43-x86_64
```

## Image build pipeline

```
ghcr.io/sunshowers/kernel-tishy:latest-f43-x86_64 → FROM ... AS kernel
ghcr.io/ublue-os/bazzite-deck:latest              → FROM ... AS tishy-deck
    ↓
install-kernel-tishy.sh:
  1. Disable dracut/rpm-ostree hooks
  2. dnf5 remove stock kernel
  3. dnf5 install custom kernel RPMs from /rpms/kernel
  4. dnf5 versionlock to pin kernel
  5. Restore hooks
    ↓
build-initramfs (rebuild initramfs for new kernel)
    ↓
ostree container commit
    ↓
ghcr.io/sunshowers/tishy-deck:latest
```

## Key design decisions

- **6.19.x kernel on Fedora 43 (ships 6.17)**: the FRL patches only exist for 6.19. Forward-compatible; kernel minor version bumps are safe.
- **No bazzite patches 1-3**: patch-1-redhat (Fedora backports) already in 6.19; patch-2-handheld not needed on desktop; patch-3-akmods dropped.
- **FRL patch includes VRR whitelist**: the FRL patch refactors the VRR PCON whitelist function and already includes the CH7218 entry, so patch-4 is unused.
- **`--with bazzite` build flag**: controls build options (no debug, no realtime, no selftests), not patches.
- **`--with ubsb` build flag**: secure boot signing. Without production MOK keys, generates self-signed test keys. User must either disable Secure Boot or enroll a custom MOK.
- **`make olddefconfig`**: the kernel.spec uses 6.17 config files but runs `make olddefconfig` to accept defaults for new 6.19 options.

## Patch provenance

The FRL patch is generated from `github.com/mkopec/linux` branch `hdmi_frl_stable` as `git diff tags/stable..hdmi_frl_stable`. The `stable` tag marks the upstream base (currently Linux 6.19.3). If mkopec rebases onto a new upstream version, the `stable` tag moves and the patch must be regenerated.
