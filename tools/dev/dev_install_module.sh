#!/system/bin/sh
# Dev helper (run as root on the Cube): install the module zip with Magisk and report the result.
# Output -> /data/local/tmp/install_out.txt
T=/data/local/tmp
O=$T/install_out.txt
Z=${1:-$T/firecube_lldv-v0.3.4.zip}
{
  echo "magisk: $(magisk -v)"
  echo "== modules before"
  ls -la /data/adb/modules
  echo "== install"
  magisk --install-module "$Z"
  echo "rc=$?"
  echo "== modules after"
  ls -la /data/adb/modules
  echo "== module files"
  ls -la /data/adb/modules/firecube_lldv
  echo "== disable/remove flags"
  ls -la /data/adb/modules/firecube_lldv/disable /data/adb/modules/firecube_lldv/remove 2>&1
  echo "== module.prop"
  cat /data/adb/modules/firecube_lldv/module.prop
  echo "== running watcher? (expect none until reboot)"
  ps -A | grep lldv_watch
  echo DONE
} > $O 2>&1
