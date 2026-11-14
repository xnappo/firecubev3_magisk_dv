#!/system/bin/sh
# Dev check (run as root on the Cube): `lldv edid` against the REAL kernel EDID, compared with the files the watcher
# loaded (/dev/lldv_p = injected EDID, /dev/lldv_o = the display's own). Output -> /data/local/tmp/edid_cmd_out.txt
T=/data/local/tmp
O=$T/edid_cmd_out.txt
export LLDV_MODDIR=$T/lldv_mod LLDV_LOG=$T/lldv.log
L="sh $T/lldv_mod/lldv"
back() { tr -d ' \n' | tr 'A-F' 'a-f' | xxd -r -p; }
{
  echo "== live EDID (stdout = hex only; stderr = summary)"
  $L edid > $T/edid_live.txt 2> $T/edid_live.err
  echo "exit: $?"
  echo "stderr: $(cat $T/edid_live.err)"
  echo "lines: $(wc -l < $T/edid_live.txt)"
  cat $T/edid_live.txt
  echo "== live EDID == /dev/lldv_p (what the watcher loaded)?"
  back < $T/edid_live.txt > $T/edid_live.bin
  ls -la /dev/lldv_p $T/edid_live.bin | cut -c1-60
  cmp $T/edid_live.bin /dev/lldv_p && echo "IDENTICAL to /dev/lldv_p"
  echo "== original EDID (lldv edid orig)"
  $L edid orig > $T/edid_orig_out.txt 2> $T/edid_orig_out.err
  echo "exit: $?   stderr: $(cat $T/edid_orig_out.err)"
  back < $T/edid_orig_out.txt > $T/edid_orig_back.bin
  cmp $T/edid_orig_back.bin /dev/lldv_o && echo "IDENTICAL to /dev/lldv_o"
  echo "== the injected block is the extra third block: lines 17-24 of the live output"
  sed -n '17,24p' $T/edid_live.txt
  echo DONE
} > $O 2>&1
