#!/system/bin/sh
# Dev helper (run as root on the Cube): narrow view of the kernel log between sleep (~uptime 985) and the watcher's
# injection (~1050). Output -> /data/local/tmp/standby_after3.txt
T=/data/local/tmp
{
  echo "uptime now: $(cat /proc/uptime)"
  echo "== plug / suspend / resume / EDID events with uptime 980..1050"
  dmesg | grep -e 'plugin$' -e 'plugout$' -e 'SWITCH_NAME=hdmi,' -e 'hpd state' -e 'Late Resume' -e 'late resume' -e 'early suspend' -e 'Early Suspend' -e 'EDID Parser' -e 'new edid loaded' -e 'dump_edid_data' -e 'hdmitx_get_edid' -e 'EARC' -e 'rxsense force' | awk -F'[][]' '{ t = $2 + 0; if (t >= 980 && t <= 1050) print }'
  echo "== watcher log tail"
  tail -n 6 $T/lldv.log
  echo DONE
} > $T/standby_after3.txt 2>&1
