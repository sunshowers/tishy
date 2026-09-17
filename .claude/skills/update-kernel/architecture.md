# kernel-tishy architecture

## Two-repo layout

```
kernel-tishy (~/dev/kernel-tishy)          tishy (~/dev/tishy)
├── KERNEL_VERSION  (7.1.3-ogc3)           ├── Containerfile.deck
├── public.key      (OGC signing key)      ├── system_files/tmp/install-kernel-tishy.sh
├── fedora/kernel.spec                      └── .github/workflows/build.yml
├── fedora/config                                (push-ghcr-deck job)
├── config/*.config.{set,unset}
├── patches/  (HDMI FRL + VRR)
├── oci.sh
└── .github/workflows/build.yml
```

**kernel-tishy** builds an OGC Fedora kernel (Linux 7.1.x) with HDMI FRL + VRR
patches as RPMs, packages them into a FROM-able OCI image, and pushes to
`ghcr.io/sunshowers/kernel-tishy`.

**tishy** (this repo) builds `tishy-deck` by starting from `bazzite-deck:latest`,
swapping the kernel with RPMs from the kernel-tishy image, and pushing to
`ghcr.io/sunshowers/tishy-deck`.

The base image follows `latest`. `KERNEL_FEDORA_VERSION` selects the Fedora
release used to build the custom kernel (currently 43); it does not select the
base image release. A newer base requires checking compatibility with these
kernel RPMs. CI derives output image tags from the base image version.

## Kernel build pipeline

```
linux-7.1.x.tar.xz (cdn.kernel.org, GPG-verified)
    +
monolithic.patch (OpenGamingCollective/linux release v7.1.x-ogcN, GPG-verified)
    ↓  applied by fedora/kernel.spec (Patch0)
patches/0001..0004 (John-Gee HDMI FRL + VRR)
    ↓  applied by fedora/kernel.spec (Patch1..4)
config merge: fedora/config + config/{fedora,ogc}.config.{set,unset}
    ↓  OpenGamingCollective/kernel-configurator action + make olddefconfig
rpmbuild -ba fedora/kernel.spec (in a Fedora container)
    ↓
kernel RPMs (kernel-core, kernel-modules, kernel-devel, kernel-tools, ...)
    ↓  oci.sh: buildah scratch, RPMs at image root
ghcr.io/sunshowers/kernel-tishy:latest-f43-x86_64
```

The build closely mirrors OGC's own `kernel-packages` Fedora workflow; the tishy
deltas are the four FRL patches and the OCI packaging step (a FROM-able image
instead of OGC's oras artifact).

## Image build pipeline

```
ghcr.io/sunshowers/kernel-tishy:latest-f43-x86_64 → FROM ... AS kernel
ghcr.io/ublue-os/bazzite-deck:latest              → FROM ... AS tishy-deck
    ↓
install-kernel-tishy.sh:
  1. Disable dracut/rpm-ostree kernel-install hooks
  2. dnf5 remove stock kernel
  3. dnf5 install custom kernel RPMs from /rpms/kernel
  4. dnf5 versionlock to pin the kernel
  5. Restore hooks
    ↓
build-initramfs (rebuild initramfs for the new kernel)
    ↓
ostree container commit
    ↓
ghcr.io/sunshowers/tishy-deck:latest
```

## Key design decisions

- **OGC 7.1.x kernel on Fedora 43**: the current FRL patch set targets 7.1. OGC
  provides Fedora-packaged 7.1 kernels (vanilla + a small signed `monolithic.patch`
  carrying the steamdeck/handheld/VRR feature set), which is exactly the base the
  John-Gee FRL patches expect.
- **Version pinned in `KERNEL_VERSION`**: a single file (`7.1.3-ogc3`) drives the
  tarball download, the OGC patch tag, and the spec version macros. Bumping it is
  the whole of a version bump.
- **FRL applied in the spec, not the config tree**: the FRL patches add no Kconfig
  symbols, so config generation runs on vanilla + `monolithic.patch` only; the FRL
  patches are applied inside rpmbuild `%prep`.
- **RPM set differs from the old bazzite kernel**: OGC's `kernel-modules` provides
  `kernel-modules-core`, `kernel-modules-extra` and `kernel-common` as virtual
  Provides rather than separate RPMs, so `install-kernel-tishy.sh` installs
  `kernel`, `kernel-core`, `kernel-modules`, `kernel-devel`, `kernel-devel-matched`,
  `kernel-tools`, `kernel-tools-libs`.
- **No Secure Boot signing**: modules are signed with an ephemeral build-time key;
  `vmlinuz` is not signed. Run with Secure Boot disabled or enroll a custom key.
- **`CONFIG_DRM_WERROR` disabled** (`config/tishy.config.unset`): OGC's base
  config enables it, but the FRL patch set is developed on CachyOS without it and
  relies on benign macro shadowing that `-Werror` rejects. See
  `kernel-tishy/patches/README.md`.
- **FROM-able OCI image**: `oci.sh` builds a scratch image with the RPMs at `/`,
  which `Containerfile.deck` bind-mounts. OGC's own build publishes an oras
  artifact, which is not FROM-able, so this step is a tishy-specific replacement.

## Patch provenance

The FRL patches come from [`github.com/John-Gee/7-1-frl`](https://github.com/John-Gee/7-1-frl)
(a CachyOS 7.1.2 PKGBUILD). `0003-hdmi-frl.patch` is adapted for OGC's stable base:
two `amdgpu_dm.c` hunks that assumed amd-staging structure are resolved to the
equivalent `dc_is_hdmi_signal(...)` swaps, and only that file's diff block is
regenerated. See `kernel-tishy/patches/README.md` for the exact resolution. The
adapted set applies with zero rejects against `v7.1.3-ogc3`.
