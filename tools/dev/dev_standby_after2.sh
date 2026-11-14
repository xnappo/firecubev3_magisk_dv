#!/system/bin/sh
# Dev helper (run as root on the Cube): list HDMI / power events by timestamp (uptime seconds), not by line number
# (dmesg is a ring buffer, so line offsets are unreliable). Output -> /data/local/tmp/standby_after2.txt
T=/data/local/tmp
{
  echo "uptime now: $(cat /proc/uptime)"
  echo "== last 60 hdmi/power/edid kernel events (timestamps are uptime seconds; baseline was at uptime 913)"
  dmesg | grep -i -e plugin -e plugout -e SWITCH_NAME=hdmi -e 'hpd state' -e 'late resume' -e 'early suspend' -e 'HDMITX: ' -e 'EDID Parser' -e 'new edid loaded' -e 'dump_edid_data' -e 'PM: suspend' -e 'wakeup' | tail -n 60
  echo "== power service wake history"
  dumpsys power | grep -i -e 'mWakefulness=' -e 'mLastWakeTime' -e 'mLastSleepTime' -e 'Wake Locks' | head -8
  echo "== process check (the watcher runs as 'sh', so grepping for its name finds nothing)"
  echo "pid file: $(cat /dev/lldv_watch.pid)  alive: $(kill -0 $(cat /dev/lldv_watch.pid) 2>&1 && echo yes)"
  echo DONE
} > $T/standby_after2.txt 2>&1
