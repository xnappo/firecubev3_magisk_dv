#!/system/bin/sh
# Dev helper (run as root on the Cube): did the installed module start at boot and do its job?
# Output -> /data/local/tmp/check_module_out.txt
E=/sys/class/amhdmitx/amhdmitx0
T=/data/local/tmp
O=$T/check_module_out.txt
M=/data/adb/modules/firecube_lldv
{
  echo "uptime: $(cat /proc/uptime)  boot_completed: $(getprop sys.boot_completed)"
  echo "bootreason: $(getprop ro.boot.bootreason)"
  echo "== module dir"
  ls -la $M
  echo "== boot-loop counter (exists only during the first 5 minutes): $(cat /data/adb/lldv_boot_count 2>&1)"
  echo "== watcher processes"
  ps -A | grep -e lldv_watch -e 'service.sh'
  echo "pid file: $(cat /dev/lldv_watch.pid 2>&1)"
  echo "== display"
  echo "hpd_state: $(cat $E/hpd_state)  sink_type: $(cat $E/sink_type)  rawedid_chars: $(cat $E/rawedid | wc -c)"
  echo "hdmi_hdr_status: $(cat $E/hdmi_hdr_status)  dv_mode: $(tail -1 /sys/class/amdolby_vision/dv_mode)"
  dumpsys display > $T/ds.txt 2>&1
  echo "android: $(grep -m1 mHdrCapabilities $T/ds.txt)"
  echo "== dv_cap2"
  cat $E/dv_cap2
  echo "== /data/adb/lldv.conf"
  cat /data/adb/lldv.conf 2>&1
  echo "== module log"
  cat $T/lldv.log 2>&1
  echo "== pstore (a panic would add a new dmesg-ramoops file/time)"
  ls -la /sys/fs/pstore
  echo DONE
} > $O 2>&1
