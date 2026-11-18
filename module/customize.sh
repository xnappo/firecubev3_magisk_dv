#!/system/bin/sh
# Magisk module installer hook (runs after the zip is extracted to $MODPATH).
SKIPMOUNT=false

DEVICE=$(getprop ro.product.device)
if [ "$DEVICE" != "gazelle" ]; then
    abort "! This module is only for the Fire TV Cube 3rd gen (gazelle), found '$DEVICE'"
fi
if [ ! -e /sys/class/amhdmitx/amhdmitx0/dv_cap2 ]; then
    abort "! /sys/class/amhdmitx/amhdmitx0/dv_cap2 not found - unsupported firmware"
fi

ui_print "- Fire TV Cube 3: Dolby Vision (LLDV) for non-DV displays"
ui_print "- Change settings:  su -c /data/adb/modules/firecube_lldv/lldv set maxlum 385"
ui_print "-                   su -c /data/adb/modules/firecube_lldv/lldv set primaries DCI-P3"
ui_print "-                   (the Action button in the Magisk app shows the current settings and status)"
ui_print "- Overrides live in /data/adb/lldv.conf and survive module updates"
ui_print "- Log: /data/local/tmp/lldv.log"
ui_print "- Boot-loop guard: the module disables itself after 4 unstable boots in a row"

set_perm_recursive "$MODPATH" 0 0 0755 0644
for f in service.sh lldv_watch.sh uninstall.sh action.sh lldv lldv_web.sh; do
    set_perm "$MODPATH/$f" 0 0 0755
done
set_perm "$MODPATH/www/cgi-bin/lldv.cgi" 0 0 0755
