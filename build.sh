#!/bin/sh
# Builds repo/home-clean_<version>_kindlehf.kpkg and the KPM repository index
set -e
cd "$(dirname "$0")"
V=$(python3 -c "import json; print('.'.join(map(str, json.load(open('package/manifest.json'))['version'])))")
PKG="home-clean_${V}_kindlehf.kpkg"
ICON=$(base64 -w0 assets/icon.png)
mkdir -p package/scriptlets
sed "s|@ICON@|$ICON|" assets/scriptlet.tmpl > package/scriptlets/HomeClean.sh
rm -rf repo
mkdir -p repo
tar --owner=0 --group=0 -czf "repo/$PKG" -C package manifest.json install.sh uninstall.sh launch.sh payload scriptlets
python3 - "$PKG" > repo/manifest.v2.json <<'PY'
import json, sys
m = json.load(open("package/manifest.json"))
print(json.dumps({
    "manifest_version": 2, "id": "home-clean", "name": "Home Clean",
    "description": "Hides the store cards from the Kindle home screen (firmware 5.20.1.0.2 only)",
    "packages": {m["id"]: {"name": m["name"], "author": m["author"], "description": m["description"],
        "artifacts": [{"url": sys.argv[1], "version": m["version"], "dependencies": [],
                       "supported_platforms": m["supported_platforms"]}]}},
}, indent=2))
PY
ls -la repo
