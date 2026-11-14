#!/system/bin/sh
# Live test (run as root on the Cube, in the background): live setting changes through the `lldv` command while
# the watcher runs. Uses the test copy in /data/local/tmp/lldv_mod and an override file in /data/local/tmp/ut, so
# the real /data/adb/lldv.conf is never touched. Stops the installed module's watcher first (its code is old).
# Box must be in the non-DV position. Needs the display's own 256-byte EDID at /dev/ed (the installed watcher
# leaves it there). Output -> /data/local/tmp/live_out.txt
E=/sys/class/amhdmitx/amhdmitx0
T=/data/local/tmp
O=$T/live_out.txt
MOD=$T/lldv_mod
LOG=$T/lldv_live2.log
export LLDV_OVERRIDE=$T/ut/live_ov.conf
export LLDV_MODDIR=$MOD
export LLDV_LOG=$LOG
export MODDIR=$MOD
: > $O
mkdir -p $T/ut

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
        echo "reported : $(grep -m1 'VSVDB:' $E/dv_cap2 | sed 's/VSVDB: //')   $(head -1 $E/dv_cap2 | cut -c1-34)"
        echo "status   : $(cat $E/hdmi_hdr_status)  rawedid_chars: $(cat $E/rawedid | wc -c)  $(grep -m1 mHdrCapabilities $T/ds.txt)"
    } >> $O
}

expect() {
    got=$(grep -m1 'VSVDB:' $E/dv_cap2 | sed 's/VSVDB: //' | tr -d '\r\n ')
    if [ "$got" = "$2" ]; then echo "PASS $1" >> $O; else echo "FAIL $1: got '$got' expected '$2'" >> $O; fi
}

restore_display() {
    printf '%s' 'load /dev/lldv_o' > $E/edid
    sleep 3
    echo 0 > $E/fake_plug
    sleep 3
    echo 1 > $E/fake_plug
    sleep 8
}

stop_watcher
rm -f $LLDV_OVERRIDE $LOG
if [ "$(wc -c < /dev/ed 2>/dev/null)" != "256" ]; then echo "/dev/ed missing or not 256 bytes, aborting" >> $O; exit 1; fi
cp /dev/ed /dev/lldv_o
snap "0 start (installed watcher stopped)"

restore_display
snap "1 display's own EDID restored (expect no DV)"
if head -1 $E/dv_cap2 | grep -q 'support list'; then echo "ABORT: display still reports DV (box not in the non-DV position?)" >> $O; exit 1; fi

nohup sh $MOD/lldv_watch.sh > /dev/null 2>&1 &
sleep 35
snap "2 watcher started, module defaults"
expect "defaults inject the base block" eb0146d0004903485798a953

sh $MOD/lldv set maxlum 1000 > $T/ut/cmd1.txt 2>&1
sleep 40
snap "3 after: lldv set maxlum 1000"
expect "live maxlum 1000 -> 1037" eb0146d0004903805798a953

sh $MOD/lldv set primaries DCI-P3 > $T/ut/cmd2.txt 2>&1
sleep 40
snap "4 after: lldv set primaries DCI-P3"
expect "live primaries DCI-P3 + maxlum 1037" eb0146d00049038089627697

sh $MOD/lldv reset > $T/ut/cmd3.txt 2>&1
sleep 40
snap "5 after: lldv reset"
expect "reset back to the base block" eb0146d0004903485798a953

printf 'PRIMARIES=rec2100\n' > $LLDV_OVERRIDE
chmod 600 $LLDV_OVERRIDE
sleep 25
snap "6 bad override (PRIMARIES=rec2100) written by hand"
expect "bad override leaves the block alone" eb0146d0004903485798a953
rm -f $LLDV_OVERRIDE
sleep 10

stop_watcher
{
    echo "=== lldv command output"
    echo "[set maxlum 1000]"; cat $T/ut/cmd1.txt
    echo "[set primaries DCI-P3]"; cat $T/ut/cmd2.txt
    echo "[reset]"; cat $T/ut/cmd3.txt
    echo "=== watcher log"
    cat $LOG
    echo "=== counts: injected=$(grep -c ' injected Dolby' $LOG) settings-changed=$(grep -c 'settings changed, re-injected' $LOG) errors=$(grep -c ERROR $LOG) warns=$(grep -c WARN $LOG)"
} >> $O

restore_display
{
    echo "cleanup: override removed: $([ -f $LLDV_OVERRIDE ] && echo NO || echo yes), real override untouched: $(ls /data/adb/lldv.conf 2>&1), $(head -1 $E/dv_cap2)"
    echo DONE
} >> $O
