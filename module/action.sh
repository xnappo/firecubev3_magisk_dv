#!/system/bin/sh
# Magisk "Action" button: step the colour primaries to the next preset and show the state.
# base > BT709 > BT2020 > DCI-P3 > LS12000 > base. For maxLum or other settings use the `lldv` command:
#   su -c /data/adb/modules/firecube_lldv/lldv show
MODDIR=${0%/*}
echo "Fire TV Cube 3 Dolby Vision (LLDV)"
echo
sh "$MODDIR/lldv" cycle
echo
sh "$MODDIR/lldv" show
