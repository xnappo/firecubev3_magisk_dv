#!/system/bin/sh
# Dev helper (run as root on the Cube): record a baseline before a standby test.
# Output -> /data/local/tmp/standby_before.txt ; marks -> /data/local/tmp/standby_marks.txt
E=/sys/class/amhdmitx/amhdmitx0
T=/data/local/tmp
dumpsys display > $T/ds.txt 2>&1
{
  echo "uptime: $(cat /proc/uptime)"
  echo "dmesg_lines: $(dmesg | wc -l)"
  echo "log_lines: $(wc -l < $T/lldv.log)"
  echo "hpd_state: $(cat $E/hpd_state)  rawedid_chars: $(cat $E/rawedid | wc -c)"
  echo "reported: $(grep -m1 VSVDB: $E/dv_cap2)  status: $(cat $E/hdmi_hdr_status)"
  echo "android: $(grep -m1 mHdrCapabilities $T/ds.txt)"
  echo "watcher pid: $(cat /dev/lldv_watch.pid)"
  echo "wakefulness: $(dumpsys power | grep -m1 mWakefulness=)"
  echo "override: $(cat /data/adb/lldv.conf 2>&1)"
} > $T/standby_before.txt 2>&1
echo "$(dmesg | wc -l) $(wc -l < $T/lldv.log)" > $T/standby_marks.txt
