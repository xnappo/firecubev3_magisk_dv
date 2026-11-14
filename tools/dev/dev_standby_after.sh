#!/system/bin/sh
# Dev helper (run as root on the Cube): what happened since dev_standby_before.sh?
# Output -> /data/local/tmp/standby_after.txt
E=/sys/class/amhdmitx/amhdmitx0
T=/data/local/tmp
read DM LG < $T/standby_marks.txt
dumpsys display > $T/ds.txt 2>&1
{
  echo "uptime: $(cat /proc/uptime)"
  echo "hpd_state: $(cat $E/hpd_state)  rawedid_chars: $(cat $E/rawedid | wc -c)"
  echo "reported: $(grep -m1 VSVDB: $E/dv_cap2)  status: $(cat $E/hdmi_hdr_status)"
  echo "android: $(grep -m1 mHdrCapabilities $T/ds.txt)"
  echo "watcher pid: $(cat /dev/lldv_watch.pid)  running: $(ps -A | grep -c lldv_watch)"
  echo "wakefulness: $(dumpsys power | grep -m1 mWakefulness=)"
  echo "== kernel log since the baseline (hdmi / suspend / resume / edid / plug lines)"
  dmesg | tail -n +$((DM + 1)) | grep -i -e plugin -e plugout -e SWITCH_NAME=hdmi -e 'hpd state' -e 'late resume' -e 'Late Resume' -e suspend -e 'EDID Parser' -e 'Edid_ParsingVendSpec' -e 'edid_store' -e 'load_edid' -e 'AMDV: new vsvdb'
  echo "== watcher log since the baseline"
  tail -n +$((LG + 1)) $T/lldv.log
  echo "== pstore"
  ls -la /sys/fs/pstore
  echo DONE
} > $T/standby_after.txt 2>&1
