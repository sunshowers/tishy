#!/usr/bin/bash

# Install the fonts the niri/DMS setup is configured to use, none of which are
# packaged in Fedora:
#
# * Figtree: DMS UI font (`fontFamily` in ~/.config/dms/settings.json).
# * Lilex Nerd Font Mono: DMS monospace font (`monoFontFamily`). Only the Mono
#   variant is installed; the proportional and Propo variants aren't used.
# * Lilex: Ghostty's font (`font-family` in ~/.config/ghostty/config).
#
# Every download is pinned to an exact upstream version and verified against a
# SHA-256 digest, so a compromised or re-tagged release fails the build rather
# than silently changing the image. To bump a font, update its version and
# digest together; GitHub shows release-asset digests via
# `gh release view <tag> -R <repo> --json assets`.

set -eoux pipefail

echo "::group::Executing install-fonts"

# Lilex 2.630 (https://github.com/mishamyrt/Lilex/releases/tag/2.630).
lilex_zip_url="https://github.com/mishamyrt/Lilex/releases/download/2.630/Lilex.zip"
lilex_zip_sha256="c946bf022f22895799eb69bcc5f2318ed4089e4e34b90054dfd78ed5316728e0"
# Lilex.zip doesn't include a license, so take it from the tagged commit.
lilex_ofl_url="https://raw.githubusercontent.com/mishamyrt/Lilex/60c93edd43922fc90685754b534a4793f0bfe408/OFL.txt"
lilex_ofl_sha256="cc3bd94cf51f40137e353fc9ca0859d54ec07e59c2092270b64a0723f4b34011"

# Nerd Fonts 3.5.1 patch of Lilex
# (https://github.com/ryanoasis/nerd-fonts/releases/tag/v3.5.1). This matches
# the base image's own nerd-fonts package (symbols only), version 3.5.1.
nf_lilex_url="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/Lilex.tar.xz"
nf_lilex_sha256="34ba9564bcb32c03d2d8e1404e72c5c4320fa99231ba99f4c566a24224f350a3"

# Figtree 2.0.3. Upstream publishes no release assets, so fetch the variable
# TTFs and license from the commit tag v2.0.3 points to. Raw files at a fixed
# commit are byte-stable, unlike GitHub's generated tag archives.
figtree_rev="be6cb018f2f93a9b1195f3dfd077123f718c65f8"
figtree_base="https://raw.githubusercontent.com/erikdkennedy/figtree/${figtree_rev}"
figtree_roman_sha256="6d7fb937ffd4ec82f3030857d910846c0d510eb1a0cb5b23f832a980de39c305"
figtree_italic_sha256="1a7657e21406f424f2d750d647c90dd122bdf401ae693601e1bda8de45a1731b"
figtree_ofl_sha256="140d37233e7f3ce7313798befa9600893bcceaf41a55fa0fa5ad52f7f657a268"

fonts_dir="/usr/share/fonts"
licenses_dir="/usr/share/licenses/tishy-fonts"

work="$(mktemp -d)"
trap 'rm -rf "$work"; echo "::endgroup::"' EXIT

# fetch URL SHA256 DEST: download URL to DEST and fail the build unless its
# digest matches.
fetch() {
    local url="$1" sha256="$2" dest="$3"
    curl -fsSL --retry 3 -o "$dest" "$url"
    echo "${sha256}  ${dest}" | sha256sum --check --strict -
}

# --- Lilex ---
fetch "$lilex_zip_url" "$lilex_zip_sha256" "$work/Lilex.zip"
fetch "$lilex_ofl_url" "$lilex_ofl_sha256" "$work/Lilex-OFL.txt"
mkdir "$work/lilex"
# The variable fonts cover every weight in two files, so the static ttf/ and
# otf/ directories aren't needed. unzip treats the [wght] in their names as a
# glob character class, so match on the directory and verify afterwards.
unzip -j "$work/Lilex.zip" 'variable/*.ttf' -d "$work/lilex"
for f in 'Lilex[wght].ttf' 'Lilex-Italic[wght].ttf'; do
    install -D -m 0644 "$work/lilex/$f" "$fonts_dir/lilex/$f"
done
install -D -m 0644 "$work/Lilex-OFL.txt" "$licenses_dir/lilex/OFL.txt"

# --- Lilex Nerd Font Mono ---
fetch "$nf_lilex_url" "$nf_lilex_sha256" "$work/LilexNerdFont.tar.xz"
mkdir "$work/nf-lilex"
tar -xJf "$work/LilexNerdFont.tar.xz" -C "$work/nf-lilex" \
    --wildcards 'LilexNerdFontMono-*.ttf' LICENSE.txt
shopt -s nullglob
nf_mono=("$work"/nf-lilex/LilexNerdFontMono-*.ttf)
shopt -u nullglob
if (( ${#nf_mono[@]} == 0 )); then
    echo "install-fonts: no LilexNerdFontMono-*.ttf in $nf_lilex_url" >&2
    exit 1
fi
install -D -m 0644 -t "$fonts_dir/lilex-nerd-font-mono" "${nf_mono[@]}"
install -D -m 0644 "$work/nf-lilex/LICENSE.txt" "$licenses_dir/lilex-nerd-font/LICENSE.txt"

# --- Figtree ---
# The brackets in the file names are percent-encoded in the URLs.
fetch "$figtree_base/fonts/variable/Figtree%5Bwght%5D.ttf" \
    "$figtree_roman_sha256" "$work/Figtree[wght].ttf"
fetch "$figtree_base/fonts/variable/Figtree-Italic%5Bwght%5D.ttf" \
    "$figtree_italic_sha256" "$work/Figtree-Italic[wght].ttf"
fetch "$figtree_base/OFL.txt" "$figtree_ofl_sha256" "$work/Figtree-OFL.txt"
install -D -m 0644 -t "$fonts_dir/figtree" \
    "$work/Figtree[wght].ttf" "$work/Figtree-Italic[wght].ttf"
install -D -m 0644 "$work/Figtree-OFL.txt" "$licenses_dir/figtree/OFL.txt"

# Refresh the system font cache so the new families are visible without each
# user's fontconfig having to rescan on first use.
fc-cache -f "$fonts_dir/lilex" "$fonts_dir/lilex-nerd-font-mono" "$fonts_dir/figtree"
