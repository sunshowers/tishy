---
name: update-kernel
description: Updates the tishy-deck custom kernel (HDMI FRL patches on Linux 6.19). Handles three scenarios: new FRL patches from mkopec/linux, base kernel version bumps, and full rebuild triggers. Use when the user mentions updating the kernel, FRL patches, kernel-tishy, or HDMI FRL.
---

# Updating the tishy-deck kernel

tishy-deck uses a custom kernel built in a separate repo (`kernel-tishy`). See [architecture.md](architecture.md) for the two-repo layout and design decisions.

## Determine the update type

Ask the user which scenario applies, then follow the corresponding workflow.

### Scenario A: new FRL patches from mkopec

The `hdmi_frl_stable` branch at `github.com/mkopec/linux` has been updated.

```
Progress:
- [ ] 1. Download the latest FRL patch artifact
- [ ] 2. Strip non-kernel diffs from the patch
- [ ] 3. Replace patch-5-hdmi-frl.patch in kernel-tishy
- [ ] 4. Commit and push to trigger a build
```

**Step 1**: Download the latest patch from the most recent workflow run.

```bash
gh run list -R mkopec/linux --branch hdmi_frl_stable --limit 1
gh run download <RUN_ID> -R mkopec/linux -n Patch -D /tmp/frl-patch
```

**Step 2**: Strip `.github/` and `.gitignore` diffs — they're repo metadata, not kernel code.

```python
import re
with open('/tmp/frl-patch/0001-amdgpu-frl.patch', 'r') as f:
    content = f.read()
parts = re.split(r'(diff --git [^\n]+\n)', content)
result = []
skip = False
for part in parts:
    if part.startswith('diff --git'):
        skip = '.github/' in part or part.strip().endswith('b/.gitignore')
    if not skip:
        result.append(part)
with open('/tmp/frl-patch/0001-amdgpu-frl.patch', 'w') as f:
    f.write(''.join(result))
```

**Step 3**: Copy to `~/dev/kernel-tishy/patch-5-hdmi-frl.patch`.

**Step 4**: Commit and push. The GitHub Actions workflow triggers on push to `main`.

### Scenario B: bump the base kernel version

A new stable kernel is out (e.g. 6.19.3 → 6.19.4) and you want to update.

```
Progress:
- [ ] 1. Verify the new version exists on cdn.kernel.org
- [ ] 2. Update version strings in kernel.spec
- [ ] 3. Verify the FRL patch base matches (check mkopec's stable tag)
- [ ] 4. Bump the pkgrelease if needed
- [ ] 5. Commit and push
```

**Step 2** — there are several version strings to update in `kernel.spec`:

```
%define specrpmversion <NEW_VERSION>
%define specversion <NEW_VERSION>
%define patchversion <MAJOR.MINOR>
%define tarfile_release <NEW_VERSION>
%define patchlevel <MINOR>
%define kabiversion <NEW_VERSION>
```

**Step 3** — the FRL patch is a diff against a `stable` tag in mkopec/linux. Check what kernel version that tag points to:

```bash
gh api repos/mkopec/linux/commits/stable --jq '.commit.message' | head -1
```

If the stable tag has moved to a new kernel version, re-download the FRL patch (scenario A). If it hasn't, the existing patch should still apply.

### Scenario C: force a full rebuild

The kernel-tishy image is already built but you want to rebuild (e.g., after config changes).

Tag the current commit and push. Tags matching `*-frl*` trigger the build workflow:

```bash
cd ~/dev/kernel-tishy
jj tag create 6.19.3-frl2  # bump the suffix as appropriate
jj git push --remote origin
```

Or trigger manually via `workflow_dispatch`:

```bash
gh workflow run build.yml -R sunshowers/kernel-tishy --ref main
```

## After the kernel builds

The kernel build takes ~2 hours. Once it completes, the OCI container is pushed to GHCR. The tishy-deck image build picks it up automatically on its next daily run, or you can trigger it:

```bash
gh workflow run build.yml -R sunshowers/tishy
```

## Deploying to the machine

```bash
sudo bootc switch --enforce-container-sigpolicy ghcr.io/sunshowers/tishy-deck:latest
# Reboot, then verify:
uname -r  # should show the frl suffix
```

Rollback if needed: `sudo bootc rollback`.
