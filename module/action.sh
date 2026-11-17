#!/system/bin/sh
# Magisk "Action" button: read-only. Prints the module version, the current configuration and display/watcher
# state with the last few log lines (`lldv show`), then example commands for changing things. It changes nothing.
MODDIR=${0%/*}
L=/data/adb/modules/firecube_lldv/lldv
V=$(grep -m1 '^version=' "$MODDIR/module.prop" | tr -d '\r')
echo "Fire TV Cube 3 Dolby Vision (LLDV) ${V#version=}"
echo
sh "$MODDIR/lldv" show
echo
echo "== change settings (run as root, e.g. from adb shell; the watcher applies a change within seconds)"
echo "su -c '$L set maxlum 385'"
echo "su -c '$L set primaries DCI-P3'     (BT709 | BT2020 | DCI-P3 | LS12000 | base)"
echo "su -c '$L cycle'                    (next primaries preset)"
echo "su -c '$L reset'                    (back to the module defaults)"
echo "su -c '$L list'                     (selectable maxLum values and presets)"
echo "su -c '$L edid'                     (EDID as hex for an EDID analyzer)"
echo "su -c '$L log 50'                   (more log lines)"
