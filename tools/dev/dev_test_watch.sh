#!/system/bin/sh
# Dev test (run as root on the Cube, in the background): simulate a non-DV display, run the watcher from
# /data/local/tmp/lldv_mod (NOT installed as a Magisk module) and report what the kernel and Android see.
# Output -> /data/local/tmp/watch_test_out.txt
E=/sys/class/amhdmitx/amhdmitx0
T=/data/local/tmp
O=$T/watch_test_out.txt
MOD=$T/lldv_mod
LOG=$T/lldv_test.log
: > $O
rm -f $LOG

snap() {
    dumpsys display > $T/ds.txt 2>&1
    {
        echo "--- $1"
        echo "dv_cap2: $(head -1 $E/dv_cap2)"
        echo "rawedid_chars: $(cat $E/rawedid | wc -c)"
        echo "hdmi_hdr_status: $(cat $E/hdmi_hdr_status)"
        echo "dv_mode: $(tail -1 /sys/class/amdolby_vision/dv_mode)"
        echo "android: $(grep -m1 mHdrCapabilities $T/ds.txt)"
    } >> $O
}

stop_watcher() {
    if [ -f /dev/lldv_watch.pid ]; then
        kill "$(cat /dev/lldv_watch.pid)" 2>/dev/null
        rm -f /dev/lldv_watch.pid
    fi
}

stop_watcher
snap "0 start"

# A: a display without DV, with Android having seen it (plug event)
echo "load /sdcard/Download/edid_nodv.bin" > $E/edid
sleep 3
echo 0 > $E/fake_plug
sleep 3
echo 1 > $E/fake_plug
sleep 8
snap "A simulated non-DV sink, Android refreshed (expect no DV, android [3 2])"

# B: start the watcher, it should inject and cycle the plug by itself
LLDV_LOG=$LOG MODDIR=$MOD nohup sh $MOD/lldv_watch.sh > /dev/null 2>&1 &
sleep 30
snap "B 30s after watcher start (expect DV, android [1 3 2])"

# C: stable, no repeated injections
sleep 12
snap "C 12s later (expect unchanged)"
echo "injections so far: $(grep -c injected $LOG)" >> $O

# D: the kernel re-reads a non-DV EDID again (what a standby wake does) -> watcher must re-inject
echo "load /sdcard/Download/edid_nodv.bin" > $E/edid
sleep 3
snap "D right after re-reading a non-DV EDID (expect no DV)"
sleep 25
snap "E 25s later (expect DV again, android [1 3 2])"

stop_watcher
{
    echo "=== watcher log"
    cat $LOG
    echo DONE
} >> $O
