#!/system/bin/sh
# Dev helper (run as root on the Cube): stop the background watcher started by dev_start_watch.sh.
if [ -f /dev/lldv_watch.pid ]; then
    kill "$(cat /dev/lldv_watch.pid)" 2>/dev/null
    rm -f /dev/lldv_watch.pid
    echo "stopped" > /data/local/tmp/stop_watch_out.txt
else
    echo "not running" > /data/local/tmp/stop_watch_out.txt
fi
