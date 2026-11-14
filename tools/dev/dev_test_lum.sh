#!/system/bin/sh
# Dev test (run on the Cube): exercise module/lldv_lum.sh with the device's own shell. Output -> /data/local/tmp/lum_out.txt
T=/data/local/tmp
O=$T/lum_out.txt
BASE=eb0146d0004903485798a953
: > $O
. $T/lldv_mod/lldv_lum.sh
{
  echo "base block: $BASE"
  for n in 0 94 100 200 372 385 400 1000 4000 10000 99999 abc 12.5 "" 007; do
    echo "maxlum '$n' -> $(lldv_apply_maxlum $BASE "$n")"
  done
  echo "== non-DV block"
  lldv_apply_maxlum eb0145d0004903485798a953 385
  echo "== uppercase"
  lldv_apply_maxlum EB0146D0004903485798A953 385
  echo "== too short"
  lldv_apply_maxlum eb0146d000 385
  echo DONE
} >> $O 2>&1
