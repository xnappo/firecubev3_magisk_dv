#!/system/bin/sh
# Dev helper (run as root on the Cube): start the watcher from /data/local/tmp/lldv_mod in the background with its
# own log (NOT installed as a Magisk module; it stops on reboot or with dev_stop_watch.sh).
T=/data/local/tmp
if [ -f /dev/lldv_watch.pid ] && kill -0 "$(cat /dev/lldv_watch.pid)" 2>/dev/null; then
    echo "already running pid $(cat /dev/lldv_watch.pid)" > $T/start_watch_out.txt
    exit 0
fi
rm -f /dev/lldv_watch.pid
: > $T/lldv_live.log
LLDV_LOG=$T/lldv_live.log MODDIR=$T/lldv_mod setsid nohup sh $T/lldv_mod/lldv_watch.sh > /dev/null 2>&1 &
sleep 3
echo "started pid $(cat /dev/lldv_watch.pid 2>/dev/null)" > $T/start_watch_out.txt
