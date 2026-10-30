#!/bin/sh
DIR=/var/local/homeclean

if cat /proc/cmdline | grep -q androidboot.veritymode; then
    echo "Cannot Install on Rootless!"
    exit 1
fi

mkdir -p "$DIR"
cp -f ./payload/homeclean.sh "$DIR/homeclean.sh"
chmod 755 "$DIR/homeclean.sh"

echo "Generating the patched bundle..."
if ! sh "$DIR/homeclean.sh" prepare; then
    rm -rf "$DIR"
    exit 1
fi

mntroot rw
cp -f ./payload/home_clean.conf /etc/upstart/home_clean.conf
mntroot ro
initctl reload-configuration

# Scriptlet name used by version 1.0.0
rm -f /mnt/us/documents/InicioSinTienda.sh
[ -f /mnt/us/documents/HomeClean.sh ] && rm -f /mnt/us/documents/HomeClean.sh
cp -f ./scriptlets/HomeClean.sh /mnt/us/documents/HomeClean.sh

echo "Installed. Open 'Home Clean' from the library to enable it."
