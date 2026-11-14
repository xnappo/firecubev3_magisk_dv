#!/system/bin/sh
# Runs dev_test_units.sh under the adb shell and under Magisk's busybox ash (standalone mode), as root.
T=/data/local/tmp
: > $T/units_out.txt
sh $T/dev_test_units.sh
ASH_STANDALONE=1 /data/adb/magisk/busybox sh $T/dev_test_units.sh
echo FINISHED >> $T/units_out.txt
