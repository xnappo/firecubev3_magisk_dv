#!/system/bin/sh
# Dev helper (run as root on the Cube): stop any running dev test script and its watcher, remove the override file.
for p in $(ps -A | grep -e dev_test_watch -e lldv_watch | grep -v grep | tr -s ' ' | cut -d' ' -f2); do
    kill "$p" 2>/dev/null
done
rm -f /dev/lldv_watch.pid /data/adb/lldv.conf
echo "stopped dev tests; remaining: $(ps -A | grep -e dev_test_watch -e lldv_watch | grep -v grep | wc -l)" > /data/local/tmp/stop_test_out.txt
