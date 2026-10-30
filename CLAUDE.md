# Home Clean

KPM package that hides the Amazon store cards from the Kindle home screen. It only supports firmware
`5.20.1.0.2`. Public repo: https://github.com/Kurut1su/kindle-home-clean. See `README.md` for usage,
how it works and porting.

## Layout

- `package/`: package source. `payload/homeclean.sh` holds the patch logic, offsets and hashes.
- `repo/`: built `.kpkg` and KPM index, committed because users install from its raw GitHub URL.
  Regenerate it with `./build.sh`, never by hand.
- `tools/find_offsets.py`: finds the patch sites in a bundle and prints the values for `homeclean.sh`.

## Rules

- User-facing text, code and docs are in English.
- Never commit Amazon code (`*.hbc`, disassembly), device credentials or IPs, or screenshots showing
  the user's documents. `CLAUDE.md` is meant to be public too.
- Bump the version in `package/manifest.json` before `./build.sh` so KPM sees an upgrade.

## Working on the Kindle

- Ask the user for the SSH address and credentials. The device uses BusyBox tools.
- KPM is at `/var/local/kmc/bin/kpm`. `kpm upgrade` upgrades every package; use
  `kpm -y install home-clean` for this one.
- Restarting `kppmainapp` by hand can show an "Application Error" dialog. It comes from the restart.
- Screenshots of the framebuffer do not test touch. Ask the user to check touch after UI changes: a
  touch freeze happened once and its cause is unknown (see Known limitations in the README).
