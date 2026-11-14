#!/system/bin/sh
# Dev test (run as root on the Cube): does Android's HdrCapabilities follow the kernel after an EDID load,
# and does a fake_plug 0/1 cycle make it re-read? Writes everything to /data/local/tmp/fw_out.txt.
E=/sys/class/amhdmitx/amhdmitx0
D=/sdcard/Download
O=/data/local/tmp/fw_out.txt
: > $O

caps() {
  dumpsys display > /data/local/tmp/ds.txt 2>&1
  {
    echo "=== $1"
    echo "dv_cap2: $(head -1 $E/dv_cap2)"
    echo "dv_cap : $(head -1 $E/dv_cap)"
    echo "hdmi_hdr_status: $(cat $E/hdmi_hdr_status)"
    echo "dv_mode: $(tail -1 /sys/class/amdolby_vision/dv_mode)"
    echo "android: $(grep -m1 mHdrCapabilities /data/local/tmp/ds.txt)"
  } >> $O
}

replug() {
  echo "--- fake_plug 0/1" >> $O
  echo 0 > $E/fake_plug
  sleep 3
  echo 1 > $E/fake_plug
  sleep 8
}

caps "START"
echo "load $D/edid_nodv.bin" > $E/edid
sleep 4
caps "1. nodv loaded, no uevent"
replug
caps "2. nodv loaded, after fake replug"
echo "load $D/edid_nodv_plus_dv3.bin" > $E/edid
sleep 4
caps "3. 3-block loaded, no uevent"
replug
caps "4. 3-block loaded, after fake replug"
echo DONE >> $O
