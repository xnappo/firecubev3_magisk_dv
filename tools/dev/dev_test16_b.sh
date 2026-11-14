#!/system/bin/sh
# Dev test, stage B (run as root on the Cube): load the patched EDID built by stage A (/dev/lldv_p) with a write of
# exactly 16 bytes, then check the kernel, Android, and a fake_plug cycle. Output -> /data/local/tmp/s16b_out.txt
E=/sys/class/amhdmitx/amhdmitx0
T=/data/local/tmp
O=$T/s16b_out.txt
: > $O

snap() {
    dumpsys display > $T/ds.txt 2>&1
    {
        echo "--- $1"
        echo "hpd: $(cat $E/hpd_state)"
        echo "dv_cap2: $(head -1 $E/dv_cap2)"
        echo "rawedid_chars: $(cat $E/rawedid | wc -c)"
        echo "hdmi_hdr_status: $(cat $E/hdmi_hdr_status)"
        echo "dv_mode: $(tail -1 /sys/class/amdolby_vision/dv_mode)"
        echo "android: $(grep -m1 mHdrCapabilities $T/ds.txt)"
    } >> $O
}

[ -s /dev/lldv_p ] || { echo "no /dev/lldv_p, run stage A first" >> $O; exit 1; }
snap "0 before"

CMD='load /dev/lldv_p'
echo "command length: ${#CMD} (must be 16)" >> $O
dmesg -c > /dev/null
printf '%s' "$CMD" > $E/edid
echo "write rc=$?" >> $O
sleep 4
snap "1 after 16-byte load (no plug event)"
echo "-- kernel log (a 'cmd format' line would mean a fragment was re-parsed):" >> $O
dmesg | grep -e edid -e EDID -e VSVDB -e hdmitx | tail -14 >> $O

echo "--- fake_plug 0/1" >> $O
echo 0 > $E/fake_plug
sleep 3
echo 1 > $E/fake_plug
sleep 10
snap "2 after fake_plug cycle"
echo DONE >> $O
