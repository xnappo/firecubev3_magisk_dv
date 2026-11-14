#!/system/bin/sh
# Dev check (run as root on the Cube): which tools behave the way the injector needs? Output -> /data/local/tmp/tools_out.txt
O=/data/local/tmp/tools_out.txt
: > $O
{
  echo "== xxd -r -p roundtrip"
  echo "00ff10" | xxd -r -p | od -An -tx1
  echo "== xxd -p"
  printf '\000\377\020' | xxd -p
  echo "== md5sum"
  echo hi | md5sum
  echo "== awk"
  echo "a b" | awk '{ print $2 }'
  echo "== busybox awk strtonum/printf"
  echo 0 | awk '{ printf "%02x\n", 171 }'
  echo "== toybox version"
  toybox --version
  echo "== getprop boot"
  getprop sys.boot_completed
  echo "== save live edid to /data/local/tmp"
  echo "save bin /data/local/tmp/live_edid.bin" > /sys/class/amhdmitx/amhdmitx0/edid
  sleep 1
  ls -la /data/local/tmp/live_edid.bin
  xxd -p /data/local/tmp/live_edid.bin | tr -d '\n' | wc -c
  echo "== setsid / nohup / timeout"
  which setsid nohup timeout
  echo DONE
} >> $O 2>&1
