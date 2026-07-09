---
name: update-kernel
description: Updates the tishy-deck custom kernel (OGC Fedora kernel 7.1.x with HDMI FRL + VRR patches). Handles three scenarios: new FRL patches from John-Gee/7-1-frl, OGC base kernel version bumps, and full rebuild triggers. Use when the user mentions updating the kernel, FRL patches, kernel-tishy, HDMI FRL, or the OGC kernel.
---

# Updating the tishy-deck kernel

tishy-deck uses a custom kernel built in a separate repo (`kernel-tishy`, at
`~/dev/kernel-tishy`). It is an [OpenGamingCollective (OGC)](https://github.com/OpenGamingCollective/kernel-packages)
Fedora kernel (vanilla `linux-7.1.x` + OGC `monolithic.patch`) with the HDMI FRL +
VRR patches from [`John-Gee/7-1-frl`](https://github.com/John-Gee/7-1-frl) layered
on top. See [architecture.md](architecture.md) for the full layout.

## Determine the update type

Ask the user which scenario applies, then follow the corresponding workflow.

### Scenario A: new FRL patches from John-Gee/7-1-frl

The `John-Gee/7-1-frl` repo has updated patches.

```
Progress:
- [ ] 1. Download the four patch files
- [ ] 2. Vendor 0001, 0002, 0004 verbatim; adapt 0003 (hdmi-frl) for the OGC base
- [ ] 3. Validate zero-reject application against the pinned OGC tag
- [ ] 4. Commit and push kernel-tishy to trigger a build
```

**Step 1**: Fetch the source files (paths are the repo's `source` array):

```bash
for f in 0001-fix-amd-color-manager.patch 0002-fix-dc-plane-cm-build-error.patch \
         hdmi_frl_amdnext.patch hdmi_vrr_amdnext.patch; do
  gh api "repos/John-Gee/7-1-frl/contents/$f" --jq '.content' | base64 -d > "/tmp/frl/$f"
done
```

**Step 2**: Map them to `kernel-tishy/patches/`:

| Source | Destination | Handling |
| --- | --- | --- |
| `0001-fix-amd-color-manager.patch` | `0001-fix-amd-color-manager.patch` | verbatim |
| `0002-fix-dc-plane-cm-build-error.patch` | `0002-fix-dc-plane-cm-build-error.patch` | verbatim |
| `hdmi_frl_amdnext.patch` | `0003-hdmi-frl.patch` | **adapt** |
| `hdmi_vrr_amdnext.patch` | `0004-hdmi-vrr.patch` | verbatim |

The upstream patches target an amd-staging ("amdnext") tree. On OGC's stable base
most files apply cleanly, but a few `amdgpu_dm.c` hunks miss because OGC lacks the
amd-staging structure. To adapt `0003-hdmi-frl.patch`:

1. Fetch the OGC source tree at the pinned tag and apply `0001`, `0002`, then
   `hdmi_frl_amdnext.patch` with `patch -p1 --fuzz=2 --forward`. Note the `.rej`.
2. Resolve each rejected hunk by making the equivalent change against OGC's code
   (the pattern is always replacing an exact `== SIGNAL_TYPE_HDMI_TYPE_A` compare
   with `dc_is_hdmi_signal(...)`; do **not** reintroduce amd-staging-only blocks).
3. Regenerate only the conflicting file's diff block and splice it back into the
   patch so every other file stays byte-identical to upstream. See
   `kernel-tishy/patches/README.md` for the recorded resolution.

**Step 3**: On a pristine copy of the OGC tag tree, apply `0001`, `0002`,
`0003-hdmi-frl.patch`, `0004-hdmi-vrr.patch` in order and confirm **zero rejects**.

**Step 4**: Commit and push `kernel-tishy`. The workflow triggers on push to `main`.

### Scenario B: bump the OGC base kernel version

A newer OGC kernel tag is out (e.g. `v7.1.3-ogc3` → `v7.1.4-ogc1`).

```
Progress:
- [ ] 1. Confirm the tag exists and has monolithic.patch assets
- [ ] 2. Update KERNEL_VERSION
- [ ] 3. Re-validate the FRL patches still apply against the new tag
- [ ] 4. Commit and push
```

**Step 1** — verify the tag and its release assets:

```bash
gh api repos/OpenGamingCollective/linux/releases/tags/v7.1.4-ogc1 \
  --jq '.assets[].name'   # expect monolithic.patch{,.sig}, public.key
```

**Step 2** — set the version in one place:

```bash
echo 7.1.4-ogc1 > ~/dev/kernel-tishy/KERNEL_VERSION
```

The spec version strings (`@@BASEKVER@@`, `@@STABLEKVER@@`, `@@OGCVER@@`,
`@@BUILDNUM@@`) are substituted from this value by the workflow; no spec edit
needed.

**Step 3** — re-run the Scenario A validation against the new tag. If the FRL
patches reject on the new base, re-adapt `0003-hdmi-frl.patch` (Scenario A step 2).
If OGC rotated their signing key, refresh `public.key` from the release assets.

### Scenario C: force a full rebuild

The image is already built but you want to rebuild (e.g. after a config change).

Tag the current commit and push (tags matching `*-frl*` trigger the workflow):

```bash
cd ~/dev/kernel-tishy
jj bookmark create 7.1.3-frl1   # or an appropriate suffix; then git push the tag
```

Or trigger manually with the version input:

```bash
gh workflow run build.yml -R sunshowers/kernel-tishy --ref main -f version=7.1.3-ogc3
```

## Local builds

`~/dev/kernel-tishy/build-local.sh` runs the same `build.sh` core as CI inside a
`fedora:43` container via podman (~15-25 min with warm ccache; the ccache lives
in `~/.cache/kernel-tishy-ccache`). It produces
`localhost/kernel-tishy:latest-f43-x86_64`. Build the deck image against it:

```bash
cd ~/dev/tishy
podman build --no-cache -f Containerfile.deck \
  --build-arg KERNEL_REF=localhost/kernel-tishy:latest-f43-x86_64 \
  -t tishy-deck:local .
```

**`--no-cache` is required when the kernel image changed**: podman does not
key the `RUN --mount=type=bind,from=kernel` layer on the kernel stage's
content, so a cached build silently ships the previous kernel with exit 0.
Verify the result before deploying:

```bash
podman run --rm localhost/tishy-deck:local \
  bash -c 'ls /usr/lib/modules/; grep CONFIG_IA32_EMULATION /usr/lib/modules/*/config'
```

## After the kernel builds in CI

The CI kernel build takes ~2.5 hours. Once it completes, the OCI image is pushed
to `ghcr.io/sunshowers/kernel-tishy:latest-f43-x86_64`. The tishy-deck build
picks it up on its next daily run, or trigger it:

```bash
gh workflow run build.yml -R sunshowers/tishy
```

## Deploying to the machine

```bash
sudo bootc switch --enforce-container-sigpolicy ghcr.io/sunshowers/tishy-deck:latest
# Reboot, then verify:
uname -r  # should show the ogc suffix, e.g. 7.1.3-ogc3.N.fc43.x86_64
```

Rollback if needed: `sudo bootc rollback`.
