#!/system/bin/sh
# Dev test (run on the Cube): lldv_apply_primaries on the device's own shell vs the python reference
# (captures/gamut_report.txt). Output -> /data/local/tmp/gamut_out.txt
T=/data/local/tmp
O=$T/gamut_out.txt
BASE=eb0146d0004903485798a953
: > $O
. $T/lldv_mod/lldv_gamut.sh
. $T/lldv_mod/lldv_lum.sh

check() {
    # $1 label  $2 got  $3 expected
    if [ "$2" = "$3" ]; then echo "PASS $1 $2"; else echo "FAIL $1 got '$2' expected '$3'"; fi
}

{
  check "BT709"            "$(lldv_apply_primaries $BASE BT709)"            eb0146d00049034899321ea7
  check "BT2020"           "$(lldv_apply_primaries $BASE BT2020)"           eb0146d0004903485798a953
  check "DCI-P3"           "$(lldv_apply_primaries $BASE DCI-P3)"           eb0146d0004903488760768f
  check "LS12000 Native"   "$(lldv_apply_primaries $BASE 'LS12000 Native')" eb0146d000490348a15855a2
  check "lowercase p3"     "$(lldv_apply_primaries $BASE p3)"               eb0146d0004903488760768f
  check "ls12000"          "$(lldv_apply_primaries $BASE ls12000)"          eb0146d000490348a15855a2
  check "bt.2020 spelling" "$(lldv_apply_primaries $BASE bt.2020)"          eb0146d0004903485798a953
  check "unknown"          "$(lldv_apply_primaries $BASE rec2100)"          "ERR:unknown primaries preset 'rec2100' (use BT709, BT2020, DCI-P3 or LS12000)"
  check "empty"            "$(lldv_apply_primaries $BASE '')"               "ERR:unknown primaries preset '' (use BT709, BT2020, DCI-P3 or LS12000)"
  check "non-dolby"        "$(lldv_apply_primaries eb0145d0004903485798a953 BT709)" "ERR:not a Dolby VSVDB"
  check "uppercase hex"    "$(lldv_apply_primaries EB0146D0004903485798A953 BT709)" "ERR:vsvdb is not lowercase hex"
  check "version 1 block"  "$(lldv_apply_primaries eb0146d0002903485798a953 BT709)" "ERR:primaries are only supported for VSVDB version 2"
  # the 10/12-bit 4:4:4 flag bits (bit 0 of bytes 8 and 9) must survive: base has byte 8 = 57 (bit0=1) and byte 9 = 98 (bit0=0)
  r=$(lldv_apply_primaries $BASE BT709)
  check "flag bit byte8"   "$((0x${r:16:2} & 1))" 1
  check "flag bit byte9"   "$((0x${r:18:2} & 1))" 0
  # untouched bytes 0..7 (header, version, interface, maxlum)
  check "bytes 0-7 kept"   "${r:0:16}" "${BASE:0:16}"
  # composition: primaries then maxlum, both orders must give the same block
  a=$(lldv_apply_maxlum "$(lldv_apply_primaries $BASE BT709)" 1000)
  b=$(lldv_apply_primaries "$(lldv_apply_maxlum $BASE 1000)" BT709)
  check "BT709 + 1000 nits" "$a" eb0146d00049038099321ea7
  check "order independent" "$b" "$a"
  echo DONE
} >> $O 2>&1
