# Speaker tuning

Windows speaker tuning data for laptops that run tishy, converted on Linux into
[EasyEffects](https://github.com/wwmm/easyeffects) presets with
[speaker-tuning-to-easyeffects](https://github.com/antoinecellerier/speaker-tuning-to-easyeffects).

None of this is part of the image. The converter's output is per machine: it is
bound to that machine's speaker output, and it lives in the user's EasyEffects
data directory.

## Framework Laptop 13 Pro (Intel Core Ultra Series 3)

[`framework-laptop-13-pro/DEV_0285_SUBSYS_F111000F_PCI_SUBSYS_000FF111.xml`](framework-laptop-13-pro/DEV_0285_SUBSYS_F111000F_PCI_SUBSYS_000FF111.xml)
is the Dolby DAX3 tuning for the Realtek ALC285 codec with subsystem ID
`0xf111000f`. To check which subsystem a laptop has, run:

```
cat /proc/asound/card*/codec#* | grep -E '^Codec|Subsystem Id'
```

The same driver bundle also carries a tuning for subsystem `0xf111010f`, a
different Framework 13 Pro configuration. It isn't kept here, since the laptop
this was set up for reports `0xf111000f`.

### Provenance

The XML is unmodified, extracted from Framework's Windows driver bundle:

| | |
|---|---|
| Download page | <https://resources.frame.work/downloads/laptop-13-pro/intel-core-ultra-3/> |
| Bundle | [`Framework_Laptop_13_Intel_Core_Ultra_Series3_driver_bundle_W11_v101_2026_06_05.exe`](https://downloads.frame.work/driver/Framework_Laptop_13_Intel_Core_Ultra_Series3_driver_bundle_W11_v101_2026_06_05.exe) (v1.01, 2026-06-05) |
| Bundle SHA-256 (published by Framework) | `32574368fcda5ff3a6a9f64a1c2f593962cd4489e6393ee2aebaa6097949badf` |
| Path in bundle | `18_Dolby_3.30904.943.0/ext_realtek_framework/ext_framework_AIO_rtk_24h2_25h2_v11.520.1207.27/` |
| XML SHA-256 | `30c9c38fe21ac32e5785c5efcee0d20f7eb0cfd6271d59c721496de735f9b008` |

It is byte-identical to the copy attached to the converter's device report for
this laptop,
[speaker-tuning-to-easyeffects#73](https://github.com/antoinecellerier/speaker-tuning-to-easyeffects/issues/73).
The file has a UTF-8 BOM and CRLF line endings, as shipped; `.gitattributes`
keeps git from normalizing them, so the checksum stays verifiable:

```
sha256sum speaker-tuning/framework-laptop-13-pro/*.xml
```

To re-extract it from a newer bundle, unpack with `7z x` and look for
`DEV_0285_SUBSYS_F111000F_*.xml` under the Dolby directory.

### Setting it up

EasyEffects is used rather than the converter's PipeWire filter-chain because on
this laptop the speakers and the 3.5 mm headphone jack are expected to be one
PipeWire sink with two ports. alsa-ucm's generic HDA profile (`ucm2/HDA/HDA.conf`)
only enables itself for dual-codec machines or ones with an AMD ACP card, so a
plain Intel HDA codec like this one gets PipeWire's non-UCM "Analog Stereo"
profile: a single sink. (That's from reading alsa-ucm 1.2.16.1 and PipeWire
1.6.10, not from observing it on the laptop; `pactl list sinks` shows the ports.)
A filter-chain attaches to the sink and would color headphones too. EasyEffects instead autoloads presets
per sink *and port*, so the speaker port gets the Dolby preset and the headphone
port falls back to a no-op `Nothing` preset.

1. Install the EasyEffects Flatpak, then open and close it once:

   ```
   flatpak install flathub com.github.wwmm.easyeffects
   ```

2. Get the converter, pinned to a release, with its Python dependencies in a
   virtual environment. Use `/usr/bin/python3` explicitly: a Python from Nix
   builds a venv whose NumPy can't find the system's `libstdc++.so.6`.

   ```
   git clone --branch v2026.10.1 https://github.com/antoinecellerier/speaker-tuning-to-easyeffects.git ~/src/speaker-tuning
   cd ~/src/speaker-tuning
   /usr/bin/python3 -m venv .venv
   .venv/bin/pip install numpy scipy rich rich-argparse
   ```

3. Generate the presets and the speaker autoload entry:

   ```
   .venv/bin/python dolby_to_easyeffects.py \
       ~/dev/tishy/speaker-tuning/framework-laptop-13-pro/DEV_0285_SUBSYS_F111000F_PCI_SUBSYS_000FF111.xml \
       --autoload
   ```

4. In EasyEffects, pick **Dolby-Balanced** under Presets. (The converter can't
   reload a Flatpak EasyEffects, so this is a one-time manual step.) Then, under
   Preferences → Background Service, turn on *Enable service mode* and
   *Autostart on login*. niri runs the resulting XDG autostart entry, as on the
   desktop.

5. Check the result:

   ```
   .venv/bin/python dolby_to_easyeffects.py --doctor
   ```

   It should report the speaker port bound to Dolby-Balanced and the global
   fallback preset set to `Nothing`. The fallback is what keeps the tuning off
   wired headphones.

### Notes

- Balanced, Detailed and Warm differ by under 1 dB anywhere in this tuning, so
  there's little to gain from comparing them; see the maintainer's analysis in
  [speaker-tuning-to-easyeffects#73](https://github.com/antoinecellerier/speaker-tuning-to-easyeffects/issues/73).
- The converter reports the result as likely quieter than Windows, because the
  tuning's volume leveler ships disabled. Re-run step 3 with
  `--enable autogain` to try it; it can make quiet passages swell, then duck.
- When a converter release's changelog entry is tagged **[AUDIBLE]**, check out
  the new tag and re-run step 3, then pick the preset again in EasyEffects.
