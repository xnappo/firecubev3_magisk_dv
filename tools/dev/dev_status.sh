#!/system/bin/sh
# Dev helper (run as root on the Cube; push it to /data/local/tmp first): one-shot status of the display and watcher.
# Output -> /data/local/tmp/status_out.txt
E=/sys/class/amhdmitx/amhdmitx0
T=/data/local/tmp
O=$T/status_out.txt
{
  echo "uptime: $(cat /proc/uptime)"
  echo "hpd_state: $(cat $E/hpd_state)  sink_type: $(cat $E/sink_type)  hdr_priority_mode: $(cat $E/hdr_priority_mode)"
  echo "dv_cap2: $(head -1 $E/dv_cap2)"
  echo "rawedid_chars: $(cat $E/rawedid | wc -c)"
  echo "hdmi_hdr_status: $(cat $E/hdmi_hdr_status)"
  echo "dv_mode: $(tail -1 /sys/class/amdolby_vision/dv_mode)"
  dumpsys display > $T/ds.txt 2>&1
  echo "android: $(grep -m1 mHdrCapabilities $T/ds.txt)"
  echo "watcher pid file: $(cat /dev/lldv_watch.pid 2>/dev/null)"
  ps -A | grep lldv_watch
  echo "--- dv_cap2 detail"
  cat $E/dv_cap2
  echo "--- watcher log"
  cat $T/lldv_live.log
  echo "--- monitor name in EDID (first CTA-visible descriptor text)"
  cat $E/rawedid | tr -d '\r\n ' | cut -c 1-64
  echo DONE
} > $O 2>&1
