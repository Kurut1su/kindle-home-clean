#!/bin/sh
DIR=/var/local/homeclean
TARGET=/app/KPPMainApp/js/KPPMainApp.js.hbc

# Upgrades keep the enabled/disabled state
[ "$1" = "upgrade" ] && exit 0

rm -f /mnt/us/documents/HomeClean.sh

if [ -f /etc/upstart/home_clean.conf ]; then
    mntroot rw
    rm -f /etc/upstart/home_clean.conf
    mntroot ro
    initctl reload-configuration
fi

grep -q " $TARGET " /proc/mounts && umount -l "$TARGET"
rm -rf "$DIR"

echo "Uninstalled. The store returns to Home after rebooting the Kindle."
