#!/system/bin/sh
# Dev test (run on the Cube): exercise module/lldv_edid.sh with the device's own shell and tools.
# Output -> /data/local/tmp/sh_out.txt
T=/data/local/tmp
O=$T/sh_out.txt
DV=eb0146d0004d4f2a96381fbf
: > $O
. $T/lldv_edid.sh

{
  echo "== nodv -> inject (expect OK)"
  lldv_patch_edid $T/edid_nodv.bin $T/res_inject.bin $DV
  echo "== inject result identical to python reference? (expect IDENTICAL)"
  if cmp -s $T/res_inject.bin $T/edid_nodv_plus_dv3.bin; then echo IDENTICAL; else echo DIFFERENT; fi
  echo "== original (already has DV) -> expect PRESENT"
  lldv_patch_edid $T/edid_orig.bin $T/res_orig.bin $DV
  echo "== already injected -> expect PRESENT"
  lldv_patch_edid $T/res_inject.bin $T/res_again.bin $DV
  echo "== base block only (128 bytes) -> expect ERR"
  head -c 128 $T/edid_nodv.bin > $T/short.bin
  lldv_patch_edid $T/short.bin $T/res_short.bin $DV
  echo "== garbage header -> expect ERR"
  head -c 256 /dev/zero > $T/zero.bin
  lldv_patch_edid $T/zero.bin $T/res_zero.bin $DV
  echo "== bad dv arg -> expect ERR"
  lldv_patch_edid $T/edid_nodv.bin $T/res_bad.bin eb0146d0
  echo "== uppercase dv arg -> expect ERR"
  lldv_patch_edid $T/edid_nodv.bin $T/res_bad.bin EB0146D0004D4F2A96381FBF
  echo "== missing input -> expect ERR"
  lldv_patch_edid $T/nonexistent.bin $T/res_bad.bin $DV
  echo "== 7-block EDID (nodv + 5 copies of block 1) -> expect OK, 8 blocks"
  { cat $T/edid_nodv.bin; for i in 1 2 3 4 5; do dd if=$T/edid_nodv.bin bs=128 skip=1 count=1 2>/dev/null; done; } > $T/seven.bin
  lldv_patch_edid $T/seven.bin $T/res_seven.bin $DV
  echo "size=$(wc -c < $T/res_seven.bin) (expect 1024)"
  echo "== 8-block EDID -> expect ERR"
  lldv_patch_edid $T/res_seven.bin $T/res_eight.bin eb0146d0004d4f2a96381fbf
  echo "== checksum check of every block in the injected EDID (expect 0 0 0)"
  for b in 0 1 2; do
    dd if=$T/res_inject.bin bs=128 skip=$b count=1 2>/dev/null | od -An -v -tu1 | tr -s ' ' '\n' | awk 'NF { s += $1 } END { print s % 256 }'
  done
  echo DONE
} >> $O 2>&1
