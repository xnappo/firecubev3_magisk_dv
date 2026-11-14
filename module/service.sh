#!/system/bin/sh
# Magisk late_start service: boot-loop guard, then wait for Android and the HDMI TX driver, then run the watcher
# (Magisk runs this script in the background, so waiting here does not delay boot).
MODDIR=${0%/*}
GLOG=/data/local/tmp/lldv.log

glog() {
    echo "$(date '+%m-%d %H:%M:%S') $*" >> "$GLOG"
}

. "$MODDIR/lldv_guard.sh"
BID=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)
R=$(lldv_guard_boot "$LLDV_GUARD_STATE" "$BID" "$LLDV_GUARD_LIMIT")
glog "boot guard: $R (limit $LLDV_GUARD_LIMIT unstable boots in a row)"
case "$R" in
    tripped:*)
        touch "$MODDIR/disable"
        glog "boot guard: module disabled; remove $MODDIR/disable (and reboot) to re-enable"
        exit 0
        ;;
esac

while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
done
while [ ! -e /sys/class/amhdmitx/amhdmitx0/dv_cap2 ]; do
    sleep 2
done

exec sh "$MODDIR/lldv_watch.sh"
