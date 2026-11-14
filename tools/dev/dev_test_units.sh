#!/system/bin/sh
# Unit tests (run as root on the Cube) for lldv_guard.sh, lldv_cfg.sh and the lldv command. Nothing here touches
# the display or /data/adb/lldv.conf: every file lives in /data/local/tmp/ut and LLDV_OVERRIDE/LLDV_LOG point there.
# Run twice: with the adb shell (sh) and with Magisk's busybox ash in standalone mode (what boot scripts get).
# Output -> /data/local/tmp/units_out.txt  (appended; the caller truncates it)
T=/data/local/tmp
U=$T/ut
M=$T/lldv_mod
O=$T/units_out.txt
rm -rf $U
mkdir -p $U
PASS=0
FAIL=0

check() {
    if [ "$2" = "$3" ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "FAIL $1: got '$2' expected '$3'"; fi
}

{
  echo "##### shell: $(readlink /proc/$$/exe) $KSH_VERSION $BASH_VERSION"
  . $M/lldv_lum.sh
  . $M/lldv_gamut.sh
  . $M/lldv_guard.sh

  echo "== guard"
  S=$U/state
  check "first boot"         "$(lldv_guard_boot $S bootA 4)" "counted:1"
  check "same boot again"    "$(lldv_guard_boot $S bootA 4)" "repeat:1"
  check "same boot 3rd time" "$(lldv_guard_boot $S bootA 4)" "repeat:1"
  check "second boot"        "$(lldv_guard_boot $S bootB 4)" "counted:2"
  check "third boot"         "$(lldv_guard_boot $S bootC 4)" "counted:3"
  check "repeat in third"    "$(lldv_guard_boot $S bootC 4)" "repeat:3"
  check "fourth boot trips"  "$(lldv_guard_boot $S bootD 4)" "tripped:4"
  check "same boot stays tripped" "$(lldv_guard_boot $S bootD 4)" "tripped:4"
  check "after re-enable restarts" "$(lldv_guard_boot $S bootE 4)" "counted:1"
  rm -f $S
  check "no state file"      "$(lldv_guard_boot $S bootF 4)" "counted:1"
  echo "garbage 99 zz" > $S
  check "huge count trips"   "$(lldv_guard_boot $S bootG 4)" "tripped:100"
  rm -f $S
  echo "garbage xx zz" > $S
  check "non-numeric count restarts" "$(lldv_guard_boot $S bootH 4)" "counted:1"
  rm -f $S
  # the Magisk-update scenario: boot, quick reboot, boot - must NOT trip
  lldv_guard_boot $S b1 4 > /dev/null; lldv_guard_boot $S b1 4 > /dev/null
  lldv_guard_boot $S b2 4 > /dev/null; lldv_guard_boot $S b2 4 > /dev/null
  check "two reboots with double service.sh runs" "$(lldv_guard_boot $S b3 4)" "counted:3"

  echo "== config layering"
  mkdir -p $U/mod
  cp $M/lldv.conf $U/mod/lldv.conf
  export LLDV_OVERRIDE=$U/lldv.conf
  rm -f $LLDV_OVERRIDE
  MODDIR=$U/mod
  . $M/lldv_cfg.sh
  lldv_effective
  check "default maxlum"     "$MAXLUM" "385"
  check "default primaries"  "$PRIMARIES" ""
  check "default effective"  "$VSVDB_EFF" "eb0146d0004903485798a953"
  echo "MAXLUM=1000" > $LLDV_OVERRIDE; chmod 600 $LLDV_OVERRIDE
  . $M/lldv_cfg.sh; lldv_effective
  check "override maxlum"    "$MAXLUM" "1000"
  check "override effective" "$VSVDB_EFF" "eb0146d0004903805798a953"
  chmod 666 $LLDV_OVERRIDE
  . $M/lldv_cfg.sh; lldv_effective
  check "world-writable override ignored" "$MAXLUM" "385"
  check "warning set"        "$([ -n "$LLDV_CFG_WARN" ] && echo yes || echo no)" "yes"
  chmod 600 $LLDV_OVERRIDE
  printf 'PRIMARIES=rec2100\nMAXLUM=abc\n' > $LLDV_OVERRIDE
  . $M/lldv_cfg.sh; lldv_effective
  check "bad values fall back to base" "$VSVDB_EFF" "eb0146d0004903485798a953"
  check "errors reported"    "$([ -n "$CFG_ERRORS" ] && echo yes || echo no)" "yes"
  printf 'POLL=0\nSETTLE=x\nHOLDOFF=\n' > $LLDV_OVERRIDE
  . $M/lldv_cfg.sh
  check "POLL=0 -> 2"        "$POLL" "2"
  check "SETTLE=x -> 3"      "$SETTLE" "3"
  check "HOLDOFF= -> 15"     "$HOLDOFF" "15"
  rm -f $LLDV_OVERRIDE

  echo "== lldv command"
  export LLDV_MODDIR=$M LLDV_LOG=$U/lldv.log
  echo "11-14 00:00:00 test line" > $LLDV_LOG
  L="sh $M/lldv"
  check "show runs"          "$($L show | grep -c '== settings')" "1"
  check "show effective"     "$($L show | grep 'effective  :' | tr -s ' ')" "effective : eb0146d0004903485798a953"
  check "list has values"    "$($L list | grep -c '94 110 129')" "1"
  check "set maxlum 1000"    "$($L set maxlum 1000 | head -1)" "MAXLUM=1037 (asked for 1000, nearest selectable step, code 16)"
  check "override content"   "$(cat $LLDV_OVERRIDE)" "MAXLUM=1037"
  check "override mode"      "$(ls -l $LLDV_OVERRIDE | cut -c1-10)" "-rw-------"
  check "set primaries p3"   "$($L set primaries p3 | head -1)" "PRIMARIES=DCI-P3"
  check "override has both"  "$(sort $LLDV_OVERRIDE | tr '\n' ' ')" "MAXLUM=1037 PRIMARIES=DCI-P3 "
  check "show effective 2"   "$($L show | grep 'effective  :' | tr -s ' ')" "effective : eb0146d00049038089627697"
  check "cycle -> LS12000"   "$($L cycle | head -1)" "primaries: DCI-P3 -> LS12000"
  check "cycle -> base"      "$($L cycle | head -1)" "primaries: LS12000 -> base"
  check "cycle -> BT709"     "$($L cycle | head -1)" "primaries: base -> BT709"
  check "set maxlum bad"     "$($L set maxlum abc 2>&1 | head -1)" "lldv: MAXLUM must be a whole number of cd/m2, got 'abc'"
  check "set primaries bad"  "$($L set primaries rec2100 2>&1 | head -1)" "lldv: unknown primaries preset 'rec2100' (use BT709, BT2020, DCI-P3 or LS12000)"
  check "override unchanged by bad input" "$(sort $LLDV_OVERRIDE | tr '\n' ' ')" "MAXLUM=1037 PRIMARIES=BT709 "
  check "set maxlum 0"       "$($L set maxlum 0 | head -1)" "MAXLUM=0 (base block's own value)"
  check "reset maxlum"       "$($L reset maxlum | head -1)" "MAXLUM override removed"
  check "override after reset maxlum" "$(cat $LLDV_OVERRIDE)" "PRIMARIES=BT709"
  check "reset primaries removes file" "$($L reset primaries >/dev/null; [ -f $LLDV_OVERRIDE ] && echo exists || echo gone)" "gone"
  check "reset all"          "$($L set maxlum 500 >/dev/null; $L reset >/dev/null; [ -f $LLDV_OVERRIDE ] && echo exists || echo gone)" "gone"
  check "log"                "$($L log 5)" "11-14 00:00:00 test line"
  check "unknown command"    "$($L frobnicate 2>&1 | head -1)" "lldv: unknown command 'frobnicate' (show, list, set, cycle, reset, log)"

  echo "== summary: PASS=$PASS FAIL=$FAIL"
} >> $O 2>&1
