#!/system/bin/sh
# Dev test (run as root on the Cube, in the background): end-to-end colour-primaries test against the CURRENT display.
# Needs the untouched display EDID at /dev/ed (256 bytes, left there by an earlier watcher run). Box must be in the
# non-DV position. For every phase: restore the display's own EDID, start the watcher with a user override in
# /data/adb/lldv.conf, and compare the VSVDB the kernel reports with the expected block.
# Output -> /data/local/tmp/watch4_out.txt
E=/sys/class/amhdmitx/amhdmitx0
T=/data/local/tmp
O=$T/watch4_out.txt
MOD=$T/lldv_mod
: > $O

stop_watcher() {
    if [ -f /dev/lldv_watch.pid ]; then
        kill "$(cat /dev/lldv_watch.pid)" 2>/dev/null
        rm -f /dev/lldv_watch.pid
    fi
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

vsvdb_now() {
    grep -m1 'VSVDB:' $E/dv_cap2 | sed 's/VSVDB: //'
}

# phase <label> <conf line(s)> <expected vsvdb>
phase() {
    restore_display
    # the non-DV message is "The Rx don't support DolbyVision" (it contains the word too), so match on "support list"
    if head -1 $E/dv_cap2 | grep -q 'support list'; then
        echo "SKIP $1: display still reports DV after restore (box not in the non-DV position?)" >> $O
        return
    fi
    echo "$2" > /data/adb/lldv.conf
    rm -f $T/lldv_p4.log
    LLDV_LOG=$T/lldv_p4.log MODDIR=$MOD nohup sh $MOD/lldv_watch.sh > /dev/null 2>&1 &
    sleep 32
    stop_watcher
    got=$(vsvdb_now)
    dumpsys display > $T/ds.txt 2>&1
    if [ "$got" = "$3" ]; then r=PASS; else r=FAIL; fi
    {
        echo "$r $1"
        echo "    conf     : $(echo "$2" | tr '\n' ' ')"
        echo "    expected : $3"
        echo "    got      : $got"
        echo "    status   : $(cat $E/hdmi_hdr_status)  rawedid_chars: $(cat $E/rawedid | wc -c)  $(grep -m1 mHdrCapabilities $T/ds.txt)"
        echo "    log      : $(grep -e injected -e ERROR $T/lldv_p4.log | tail -2 | tr '\n' '|')"
    } >> $O
}

stop_watcher
rm -f /data/adb/lldv.conf
if [ "$(wc -c < /dev/ed 2>/dev/null)" != "256" ]; then echo "/dev/ed missing or not 256 bytes, aborting" >> $O; exit 1; fi
cp /dev/ed /dev/lldv_o

phase "BT709"          "PRIMARIES=BT709"            eb0146d00049034899321ea7
# BT2020 floored equals the default base block's own primaries, so this phase expects the base block unchanged
phase "BT2020"         "PRIMARIES=BT2020"           eb0146d0004903485798a953
phase "DCI-P3"         "PRIMARIES=DCI-P3"           eb0146d0004903488760768f
phase "LS12000 Native" "PRIMARIES=LS12000"          eb0146d000490348a15855a2
phase "DCI-P3 + MAXLUM 1000" "PRIMARIES=DCI-P3
MAXLUM=1000"                                         eb0146d0004903808760768f
phase "bad preset ignored (base block kept)" "PRIMARIES=rec2100" eb0146d0004903485798a953

# leave the Cube on the display's own EDID, with no override file and no watcher
stop_watcher
rm -f /data/adb/lldv.conf
restore_display
{
    echo "cleanup: override file removed: $([ -f /data/adb/lldv.conf ] && echo NO || echo yes), display EDID restored: $(cat $E/rawedid | wc -c) chars, $(head -1 $E/dv_cap2)"
    echo DONE
} >> $O
