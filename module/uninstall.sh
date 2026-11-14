#!/system/bin/sh
# Magisk uninstall hook: stop the watcher and remove its working files. The kernel's EDID returns to the
# display's own on the next hotplug or reboot.
if [ -f /dev/lldv_watch.pid ]; then
    kill "$(cat /dev/lldv_watch.pid)" 2>/dev/null
    rm -f /dev/lldv_watch.pid
fi
rm -rf /data/local/tmp/lldv /data/local/tmp/lldv.log /data/local/tmp/lldv.log.tmp /data/adb/lldv_boot_count
rm -f /dev/ed /dev/lldv_p /dev/lldv_o
