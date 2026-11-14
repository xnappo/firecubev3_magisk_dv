#!/system/bin/sh
# Dev test (run as root on the Cube): load no-DV EDID, then the 3-block EDID, and report what the kernel and Android see.
E=/sys/class/amhdmitx/amhdmitx0
D=/sdcard/Download

show() {
  echo "=== $1"
  echo "dv_cap: $(head -1 $E/dv_cap)"
  echo "rawedid_chars: $(cat $E/rawedid | wc -c)"
  echo "hdmi_hdr_status: $(cat $E/hdmi_hdr_status)"
  echo "android: $(dumpsys display | grep -m1 mHdrCapabilities)"
  echo "dv_mode: $(tail -1 /sys/class/amdolby_vision/dv_mode)"
}

show "BEFORE"
echo "load $D/edid_nodv.bin" > $E/edid
sleep 5
show "AFTER NODV LOAD"
echo "load $D/edid_nodv_plus_dv3.bin" > $E/edid
sleep 5
show "AFTER 3-BLOCK LOAD"
