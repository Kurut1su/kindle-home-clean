# Home Clean

Removes the Amazon store cards from the Kindle home screen, leaving only your recent items.
You can turn it on and off from the library.

> [!WARNING]
> **This patch ONLY works on Kindle firmware `5.20.1.0.2`.**
> It has only been tested on a Kindle Scribe (device type `A12KI9K1KHHBVF`).
> On any other firmware it refuses to install. A firmware update turns it off, and the patch
> has to be [ported](#porting-to-another-firmware) to the new version.

Check your version under *Settings > Device Options > Device Info*, or over SSH:

```sh
cat /etc/prettyversion.txt
```

Being on `5.20.1.0.2` is not enough on its own: the bundle hash must also match. Another model on
the same firmware may have a different bundle, in which case the patch refuses to install.

## Requirements

- Firmware `5.20.1.0.2`
- A jailbroken Kindle with [KPM](https://kindlemodding.org) (`kindlehf` builds only)
- Internet access on the Kindle for the install method below

## Install

Run this on the Kindle, over SSH or from a terminal such as kTerm:

```sh
K=/var/local/kmc/bin/kpm
$K add-repo https://raw.githubusercontent.com/Kurut1su/kindle-home-clean/main/repo/manifest.v2.json
$K update
$K -y install home-clean
```

Installing does not enable the patch.

## Use

**On the Kindle:** open **Home Clean** from the library. It switches state and reboots.

**Over SSH:**

```sh
/var/local/kmc/bin/kpm launch home-clean on      # hide the store and reboot
/var/local/kmc/bin/kpm launch home-clean off     # show the store and reboot
/var/local/kmc/bin/kpm launch home-clean toggle  # switch state and reboot
/var/local/kmc/bin/kpm launch home-clean status  # show the current state
```

## Uninstall

```sh
/var/local/kmc/bin/kpm uninstall home-clean
```

The store returns to the home screen after the next reboot.

## How it works

The home screen is part of a Hermes bytecode bundle, `/app/KPPMainApp/js/KPPMainApp.js.hbc`.
No setting or flag was found that hides these cards on this firmware, so a copy of the bundle is
patched instead.

1. `homeclean.sh` generates the patched copy **on the device**, in `/var/local/homeclean/`. This
   repository does not contain any Amazon code, only the bytes to change.
2. An upstart job, `/etc/upstart/home_clean.conf`, runs before each `KPPMainApp` start and
   bind-mounts the copy over the original if the patch is enabled.

The original bundle is never modified. The upstart job is the only file added to the root
filesystem.

| Offset | Bytes | Function | Effect |
|---|---|---|---|
| 3863078 | `88 3c 01 00 00` | #12365, `LegacyHomeView` card factory | After the library card, jump to `return null` |
| 4044292 | `88 3c 01 00 00` | #13429, `HomeFeed` card factory | Same |
| 3868022 | `6a 04 00` | #12384, pagination callback | Height 0 for all cards but the first, so no empty pages remain |
| 10034572 | 20 bytes | File footer | Recalculated SHA-1 |

## Safety checks

- **Wrong firmware:** nothing is patched or mounted unless the firmware version and the SHA-256 of
  the bundle both match.
- **Crash loop:** after more than 5 app starts in one boot, the patch unmounts and disables itself.
- **Kill switch:** create an empty file named `HOMECLEAN_DISABLE` in the root of the Kindle's USB
  storage (`/mnt/us/`) and reboot. The patch is not mounted while the file exists. Use this if you
  cannot use the touchscreen or SSH.

## Known limitations

- Cards are hidden when they are drawn. The Kindle still downloads them from Amazon.
- Everything below the first card is hidden. That includes any other card Amazon shows there, and
  the first card must be your recent items for the layout to work.
- The cart icon stays in the top bar, so the store is still reachable. Parental controls are
  unaffected.
- **Possible touch freeze:** the touchscreen stopped responding once, shortly after the first boot
  with the patch. It recovered without intervention and did not recur in later testing. The cause
  is unknown and the patch has not been ruled out. Reports are welcome.

## Porting to another firmware

`tools/find_offsets.py` finds the patch sites by their code structure and builds a patched bundle:

```sh
pip install hermes-dec
scp root@<kindle-ip>:/app/KPPMainApp/js/KPPMainApp.js.hbc .
python3 tools/find_offsets.py KPPMainApp.js.hbc KPPMainApp.patched.hbc
```

If the code has changed too much, it stops with an error. A successful run is not proof the patch
is correct, so test it before publishing:

1. Bind-mount the output over the original bundle. A reboot undoes this:

   ```sh
   initctl stop kppmainapp
   mount --bind /path/to/KPPMainApp.patched.hbc /app/KPPMainApp/js/KPPMainApp.js.hbc
   initctl start kppmainapp
   ```

   Restarting the app by hand can show an "Application Error" dialog. It comes from the restart.
2. Check the home screen, the touchscreen and scrolling.
3. Copy the printed values into `package/payload/homeclean.sh`, and update `SUPPORTED_FW` and the
   version in `package/manifest.json`.
4. Run `./build.sh` to regenerate `repo/`.

Please open a pull request if you get it working on another firmware.

## Disclaimer

This is an unofficial project, not affiliated with or endorsed by Amazon. Modifying your device is
at your own risk and may affect your warranty. The software comes with no warranty.

## License

[MIT](LICENSE)
