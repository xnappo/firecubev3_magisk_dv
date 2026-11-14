#!/system/bin/sh
# Dev test (run as root on the Cube, in the background): run the 16-byte-write watcher from /data/local/tmp/lldv_mod
# (NOT installed as a Magisk module) against the CURRENT display and report what the kernel and Android see.
# Output -> /data/local/tmp/watch2_out.txt
E=/sys/class/amhdmitx/amhdmitx0
T=/data/local/tmp
O=$T/watch2_out.txt
MOD=$T/lldv_mod
LOG=$T/lldv_test.log
: > $O
rm -f $LOG

snap() {
    dumpsys display > $T/ds.txt 2>&1
    {
        echo "--- $1"
        echo "hpd: $(cat $E/hpd_state)  dv_cap2: $(head -1 $E/dv_cap2)"
        echo "rawedid_chars: $(cat $E/rawedid | wc -c)  hdmi_hdr_status: $(cat $E/hdmi_hdr_status)"
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

# Needs the untouched display EDID at /dev/ed (stage A of the 16-byte test left it there). 'load /dev/lldv_o' is 16 bytes.
if [ ! -s /dev/ed ]; then echo "no /dev/ed (original EDID), run dev_test16_a.sh first" >> $O; exit 1; fi
cp /dev/ed /dev/lldv_o

# 1: put the display's own (no-DV) EDID back and let Android see it
printf '%s' 'load /dev/lldv_o' > $E/edid
sleep 3
echo 0 > $E/fake_plug
sleep 3
echo 1 > $E/fake_plug
sleep 8
snap "1 display's own EDID loaded, Android refreshed (box non-DV position: expect no DV, android [2])"

# 2: start the watcher; it should inject and cycle the plug by itself
LLDV_LOG=$LOG MODDIR=$MOD nohup sh $MOD/lldv_watch.sh > /dev/null 2>&1 &
sleep 35
snap "2 35s after watcher start (expect DV, android [1 2])"

# 3: stable, no repeated injections
sleep 25
snap "3 25s later (expect unchanged)"
echo "injections so far: $(grep -c injected $LOG)  (expect 1)" >> $O

# 4: the kernel re-reads the display's no-DV EDID again (what a standby wake does) -> watcher must re-inject
printf '%s' 'load /dev/lldv_o' > $E/edid
sleep 3
snap "4 right after re-reading the no-DV EDID (expect no DV)"
sleep 35
snap "5 35s later (expect DV again, android [1 2])"
echo "injections so far: $(grep -c injected $LOG)  (expect 2)" >> $O

stop_watcher
{
    echo "=== watcher log"
    cat $LOG
    echo DONE
} >> $O
