#!/system/bin/sh
# Dev test (run as root on the Cube, in the background): end-to-end maxLum test against the CURRENT display.
# Needs the untouched display EDID at /dev/ed (left there by an earlier watcher run). Box must be in the non-DV position.
#   phase 1: module defaults (MAXLUM=385 -> base block unchanged)
#   phase 2: user override /data/adb/lldv.conf with MAXLUM=1000 (removed again at the end)
# Output -> /data/local/tmp/watch3_out.txt
E=/sys/class/amhdmitx/amhdmitx0
T=/data/local/tmp
O=$T/watch3_out.txt
MOD=$T/lldv_mod
: > $O

stop_watcher() {
    if [ -f /dev/lldv_watch.pid ]; then
        kill "$(cat /dev/lldv_watch.pid)" 2>/dev/null
        rm -f /dev/lldv_watch.pid
    fi
}

snap() {
    dumpsys display > $T/ds.txt 2>&1
    {
        echo "--- $1"
        echo "hpd: $(cat $E/hpd_state)  rawedid_chars: $(cat $E/rawedid | wc -c)"
        echo "hdmi_hdr_status: $(cat $E/hdmi_hdr_status)  dv_mode: $(tail -1 /sys/class/amdolby_vision/dv_mode)"
        echo "$(grep -m1 VSVDB: $E/dv_cap2)   modes: $(sed -n '/Support mode/,/IEEEOUI/p' $E/dv_cap2 | grep -v -e 'Support mode' -e IEEEOUI | tr -d '\n')"
        echo "android: $(grep -m1 mHdrCapabilities $T/ds.txt)"
    } >> $O
}

# put the display's own EDID back and let Android see it (every edid write is exactly 16 bytes)
restore_display() {
    printf '%s' 'load /dev/lldv_o' > $E/edid
    sleep 3
    echo 0 > $E/fake_plug
    sleep 3
    echo 1 > $E/fake_plug
    sleep 8
}

stop_watcher
rm -f /data/adb/lldv.conf
if [ ! -s /dev/ed ]; then echo "no /dev/ed (original EDID)" >> $O; exit 1; fi
cp /dev/ed /dev/lldv_o
snap "0 start"

restore_display
snap "1 display's own EDID restored (expect no DV)"

rm -f $T/lldv_p3a.log
LLDV_LOG=$T/lldv_p3a.log MODDIR=$MOD nohup sh $MOD/lldv_watch.sh > /dev/null 2>&1 &
sleep 35
snap "2 phase 1: module defaults (expect VSVDB eb0146d0004903485798a953, DolbyVision-Lowlatency)"
stop_watcher

restore_display
snap "3 display's own EDID restored again (expect no DV)"

echo 'MAXLUM=1000' > /data/adb/lldv.conf
rm -f $T/lldv_p3b.log
LLDV_LOG=$T/lldv_p3b.log MODDIR=$MOD nohup sh $MOD/lldv_watch.sh > /dev/null 2>&1 &
sleep 35
snap "4 phase 2: user override MAXLUM=1000 (expect VSVDB eb0146d0004903805798a953)"
stop_watcher
rm -f /data/adb/lldv.conf

{
    echo "=== log phase 1"
    cat $T/lldv_p3a.log
    echo "=== log phase 2"
    cat $T/lldv_p3b.log
    echo "override file removed: $([ -f /data/adb/lldv.conf ] && echo NO || echo yes)"
    echo DONE
} >> $O
