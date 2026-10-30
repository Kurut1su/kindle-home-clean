#!/bin/sh
# Home Clean: bind-mounts a patched copy of the home app bundle at boot.
# ONLY for firmware 5.20.1.0.2. The firmware files are never modified: without the mount,
# the Kindle runs the original bundle.
DIR=/var/local/homeclean
TARGET=/app/KPPMainApp/js/KPPMainApp.js.hbc
PATCHED=$DIR/KPPMainApp.patched.hbc
ENABLED=$DIR/enabled
STARTS=/tmp/homeclean.starts
KILL_SWITCH=/mnt/us/HOMECLEAN_DISABLE
MAX_STARTS=5
SUPPORTED_FW=5.20.1.0.2
# Bundle hashes for the supported firmware, original and patched
SHA_ORIG=44e55c15e260c0327e27694a8e853ab88807cc7c400f41f10e1e85fc3a2301d4
SHA_PATCHED=390f74f667129575430b03825ae9c45573ece635466827274dbaa17ac409f24c

sha() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }
is_mounted() { grep -q " $TARGET " /proc/mounts; }
log() { logger -t homeclean "$1" 2>/dev/null; }
fw_version() { sed -n 's/^Kindle \([0-9.]*\).*/\1/p' /etc/prettyversion.txt 2>/dev/null; }

say() {
    echo "$1"
    [ -x /var/local/kmc/bin/fbink ] && /var/local/kmc/bin/fbink -q -m -y "${2:-30}" "$1" 2>/dev/null
}

poke() { # poke <offset> <octal bytes>
    printf "$2" | dd of="$PATCHED.tmp" bs=1 seek="$1" conv=notrunc 2>/dev/null
}

prepare() {
    if [ "$(fw_version)" != "$SUPPORTED_FW" ]; then
        echo "Unsupported firmware $(fw_version). Home Clean only works on $SUPPORTED_FW."
        return 1
    fi
    [ "$(sha "$PATCHED")" = "$SHA_PATCHED" ] && return 0
    if is_mounted || [ "$(sha "$TARGET")" != "$SHA_ORIG" ]; then
        echo "Unsupported device: the home app bundle does not match the known $SUPPORTED_FW build."
        return 1
    fi
    mkdir -p "$DIR"
    cp "$TARGET" "$PATCHED.tmp" || return 1
    # LegacyHomeView and HomeFeed: after the library card, jump to the final "return null"
    poke 3863078 '\210\074\001\000\000'
    poke 4044292 '\210\074\001\000\000'
    # Pagination: height 0 for every card but the first, so no empty pages are left
    poke 3868022 '\152\004\000'
    # Hermes file footer (SHA-1)
    poke 10034572 '\170\007\311\374\234\052\262\043\032\272\375\044\011\012\117\271\374\320\075\045'
    if [ "$(sha "$PATCHED.tmp")" != "$SHA_PATCHED" ]; then
        rm -f "$PATCHED.tmp"
        echo "Patching did not produce the expected result."
        return 1
    fi
    chmod 644 "$PATCHED.tmp"
    mv "$PATCHED.tmp" "$PATCHED"
}

# Called by upstart before every KPPMainApp start. It must always exit cleanly.
boot_mount() {
    n=$(cat "$STARTS" 2>/dev/null); n=$(( ${n:-0} + 1 )); echo "$n" > "$STARTS"
    if [ ! -f "$ENABLED" ] || [ -e "$KILL_SWITCH" ]; then
        is_mounted && umount -l "$TARGET"
        return 0
    fi
    # If the app keeps restarting, go back to the original and stay disabled
    if [ "$n" -gt "$MAX_STARTS" ]; then
        log "too many KPPMainApp starts, disabling"
        rm -f "$ENABLED"
        is_mounted && umount -l "$TARGET"
        return 0
    fi
    is_mounted && return 0
    if [ "$(sha "$TARGET")" != "$SHA_ORIG" ] || [ "$(sha "$PATCHED")" != "$SHA_PATCHED" ]; then
        log "bundle hash mismatch (different firmware?), not mounting"
        return 0
    fi
    mount --bind "$PATCHED" "$TARGET" || log "mount failed"
    return 0
}

status() {
    state=disabled; [ -f "$ENABLED" ] && state=enabled
    active=no; is_mounted && active=yes
    echo "Home Clean: $state (patch mounted now: $active, firmware: $(fw_version))"
}

apply() { # apply on|off
    if [ "$1" = on ]; then
        msg=$(prepare) || { say "$msg"; sleep 5; return 1; }
        touch "$ENABLED"
        say "Store hidden from Home. Rebooting..."
    else
        rm -f "$ENABLED"
        say "Store visible on Home. Rebooting..."
    fi
    sync
    sleep 4
    reboot
}

case "$1" in
    prepare) prepare ;;
    mount) boot_mount; exit 0 ;;
    on) apply on ;;
    off) apply off ;;
    toggle) if [ -f "$ENABLED" ]; then apply off; else apply on; fi ;;
    status|"") status ;;
    *) echo "usage: $0 {on|off|toggle|status}"; exit 2 ;;
esac
