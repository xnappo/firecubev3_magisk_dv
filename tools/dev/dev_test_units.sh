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
  _expected_ver=$(grep -m1 '^version=' $M/module.prop | tr -d '\r')
  _expected_ver=${_expected_ver#version=}
  check "show runs"          "$($L show | grep -c '== settings')" "1"
  check "show version"       "$($L show | head -1 | tr -s ' ')" "version : $_expected_ver"
  check "show effective"     "$($L show | grep 'effective  :' | tr -s ' ')" "effective : eb0146d0004903485798a953"
  check "list has values"    "$($L list | grep -c '94 110 129')" "1"
  check "set maxlum 1000"    "$($L set maxlum 1000 | head -1)" "MAXLUM=1037 (asked for 1000, nearest selectable step, code 16)"
  check "override content"   "$(cat $LLDV_OVERRIDE)" "MAXLUM=1037"
  check "override mode"      "$(ls -l $LLDV_OVERRIDE | cut -c1-10)" "-rw-------"
  check "set primaries p3"   "$($L set primaries p3 | head -1)" "PRIMARIES=DCI-P3"
  check "override has both"  "$(sort $LLDV_OVERRIDE | tr '\n' ' ')" "MAXLUM=1037 PRIMARIES=DCI-P3 "
  check "show effective 2"   "$($L show | grep 'effective  :' | tr -s ' ')" "effective : eb0146d0004903808760768f"
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
  check "set web enabled"    "$($L set web enabled | head -1)" "WEB=1 WEB_PORT=18765 written to $LLDV_OVERRIDE"
  check "override after set web enabled" "$(sort $LLDV_OVERRIDE | tr '\n' ' ')" "WEB=1 WEB_PORT=18765 "
  check "override mode after set web" "$(ls -l $LLDV_OVERRIDE | cut -c1-10)" "-rw-------"
  $L set primaries DCI-P3 >/dev/null
  check "set web enabled:8080" "$($L set web enabled:8080 | head -1)" "WEB=1 WEB_PORT=8080 written to $LLDV_OVERRIDE"
  check "override preserves primaries + updates web port" "$(sort $LLDV_OVERRIDE | tr '\n' ' ')" "PRIMARIES=DCI-P3 WEB=1 WEB_PORT=8080 "
  check "set web bad arg"    "$($L set web enable 2>&1 | head -1)" "lldv: usage: lldv set web enabled[:port]"
  check "set web bad port non-numeric" "$($L set web enabled:abc 2>&1 | head -1)" "lldv: web port must be numeric, got 'abc'"
  check "set web bad port low" "$($L set web enabled:80 2>&1 | head -1)" "lldv: web port must be 1024..65535, got '80'"
  check "set web bad port high" "$($L set web enabled:70000 2>&1 | head -1)" "lldv: web port must be 1024..65535, got '70000'"
  check "override unchanged by bad web input" "$(sort $LLDV_OVERRIDE | tr '\n' ' ')" "PRIMARIES=DCI-P3 WEB=1 WEB_PORT=8080 "
  $L reset >/dev/null
  check "log"                "$($L log 5)" "11-14 00:00:00 test line"
  check "unknown command"    "$($L frobnicate 2>&1 | head -1)" "lldv: unknown command 'frobnicate' (show, list, set, cycle, reset, edid, log)"

  echo "== lldv edid"
  # test inputs: the 2-block EDID of the development TV (captures/edid_orig.bin, pushed to /data/local/tmp)
  SRC=$T/edid_orig.bin
  if [ "$(wc -c < $SRC 2>/dev/null)" != "256" ]; then
      FAIL=$((FAIL + 1)); echo "FAIL edid tests need $SRC (256 bytes)"
  else
      od -An -v -tx1 $SRC | tr -d ' \012' > $U/live.hex
      echo >> $U/live.hex
      export LLDV_RAWEDID=$U/live.hex LLDV_ORIGEDID=$U/orig.bin
      rm -f $U/orig.bin
      $L edid > $U/edid_out.txt 2> $U/edid_err.txt
      check "edid exit status"     "$?" "0"
      check "edid line count"      "$(wc -l < $U/edid_out.txt | tr -d ' ')" "16"
      check "edid first line"      "$(head -1 $U/edid_out.txt)" "00 FF FF FF FF FF FF 00 59 3A 39 10 01 01 01 01"
      check "edid last line"       "$(tail -1 $U/edid_out.txt)" "0A E3 05 E0 00 00 00 00 00 00 00 00 00 00 00 14"
      check "edid stdout is only hex" "$(grep -c -v '^[0-9A-F][0-9A-F]\( [0-9A-F][0-9A-F]\)*$' $U/edid_out.txt)" "0"
      check "edid stderr summary"  "$(cat $U/edid_err.txt)" "# live EDID: 2 blocks (256 bytes), header and checksums ok"
      # this toybox's `xxd -r -p` silently drops UPPERCASE hex (00 FF FF -> 00), so lowercase it before reversing
      tr -d ' \n' < $U/edid_out.txt | tr 'A-F' 'a-f' | xxd -r -p > $U/edid_back.bin
      check "edid round trip"      "$(cmp $U/edid_back.bin $SRC >/dev/null 2>&1 && echo same || echo different)" "same"
      check "edid round trip size" "$(wc -c < $U/edid_back.bin | tr -d ' ')" "256"
      check "edid live explicit"   "$($L edid live 2>/dev/null | head -1)" "00 FF FF FF FF FF FF 00 59 3A 39 10 01 01 01 01"
      # lowercase / CRLF input from the kernel node is normalised
      tr 'A-F' 'a-f' < $U/live.hex | sed 's/$/\r/' > $U/live_lc.hex
      LLDV_RAWEDID=$U/live_lc.hex $L edid > $U/edid_lc.txt 2>/dev/null
      check "edid lowercase+CRLF normalised" "$(head -1 $U/edid_lc.txt)" "00 FF FF FF FF FF FF 00 59 3A 39 10 01 01 01 01"
      # a bad checksum in block 1 and a bad header are reported, not hidden
      # the last byte of the development EDID is its block-1 checksum (0x14): rewriting it to 0x15 must be flagged
      { printf '%s' "$(tr -d '\n' < $U/live.hex | cut -c1-510)"; echo 15; } > $U/live_badsum.hex
      check "edid bad checksum flagged" "$(LLDV_RAWEDID=$U/live_badsum.hex $L edid 2>&1 >/dev/null)" "# live EDID: 2 blocks (256 bytes), BAD CHECKSUM in block(s): 1"
      # and rewriting it to its true value keeps the summary clean
      { printf '%s' "$(tr -d '\n' < $U/live.hex | cut -c1-510)"; echo 14; } > $U/live_goodsum.hex
      check "edid good checksum ok" "$(LLDV_RAWEDID=$U/live_goodsum.hex $L edid 2>&1 >/dev/null)" "# live EDID: 2 blocks (256 bytes), header and checksums ok"
      { printf '11'; tr -d '\n' < $U/live.hex | cut -c3-; } > $U/live_badhdr.hex
      check "edid bad header flagged" "$(LLDV_RAWEDID=$U/live_badhdr.hex $L edid 2>&1 >/dev/null | grep -c 'BAD HEADER')" "1"
      printf 'ZZ\n' > $U/live_junk.hex
      check "edid non-hex rejected" "$(LLDV_RAWEDID=$U/live_junk.hex $L edid 2>&1 | head -1)" "lldv: the EDID source did not contain plain hex"
      : > $U/live_empty.hex
      LLDV_RAWEDID=$U/live_empty.hex $L edid > $U/e1.txt 2>&1
      check "edid empty source: one clean line" "$(wc -l < $U/e1.txt | tr -d ' ')" "1"
      check "edid empty source: message"        "$(grep -c '^lldv: no EDID available from ' $U/e1.txt)" "1"
      LLDV_RAWEDID=$U/nonexistent $L edid > $U/e2.txt 2>&1
      check "edid missing source: one clean line" "$(wc -l < $U/e2.txt | tr -d ' ')" "1"
      check "edid missing source: message"        "$(grep -c '^lldv: no EDID available from ' $U/e2.txt)" "1"
      # orig
      $L edid orig > $U/e3.txt 2>&1
      check "edid orig without saved file: one clean line" "$(wc -l < $U/e3.txt | tr -d ' ')" "1"
      check "edid orig without saved file: message" "$(grep -c '^lldv: no saved original EDID: ' $U/e3.txt)" "1"
      cp $SRC $U/orig.bin
      check "edid orig first line" "$($L edid orig 2>/dev/null | head -1)" "00 FF FF FF FF FF FF 00 59 3A 39 10 01 01 01 01"
      check "edid orig summary"    "$($L edid orig 2>&1 >/dev/null)" "# original EDID (as saved before the module injected): 2 blocks (256 bytes), header and checksums ok"
      check "edid usage"           "$($L edid frobnicate 2>&1 | head -1)" "lldv: usage: lldv edid [orig]"
      # a 3-block (injected) EDID: 24 lines, 3 blocks
      if [ "$(wc -c < $T/edid_nodv_plus_dv3.bin 2>/dev/null)" = "384" ]; then
          od -An -v -tx1 $T/edid_nodv_plus_dv3.bin | tr -d ' \012' > $U/live3.hex
          check "edid 3 blocks lines"  "$(LLDV_RAWEDID=$U/live3.hex $L edid 2>/dev/null | wc -l | tr -d ' ')" "24"
          check "edid 3 blocks summary" "$(LLDV_RAWEDID=$U/live3.hex $L edid 2>&1 >/dev/null)" "# live EDID: 3 blocks (384 bytes), header and checksums ok"
          printf '0000000000000000\n' > $U/live_zero.hex
          check "edid all-zero standby fallback lines" "$(LLDV_RAWEDID=$U/live_zero.hex LLDV_PATCHEDEDID=$T/edid_nodv_plus_dv3.bin $L edid 2>/dev/null | wc -l | tr -d ' ')" "24"
          check "edid all-zero standby fallback summary" "$(LLDV_RAWEDID=$U/live_zero.hex LLDV_PATCHEDEDID=$T/edid_nodv_plus_dv3.bin $L edid 2>&1 >/dev/null | grep -c 'all-zero in standby')" "1"
          check "edid all-zero without patched file fails" "$(LLDV_RAWEDID=$U/live_zero.hex LLDV_PATCHEDEDID=$U/nonexistent $L edid 2>&1 | grep -c '^lldv: no EDID available from ')" "1"
      fi
      unset LLDV_RAWEDID LLDV_ORIGEDID LLDV_PATCHEDEDID
  fi

  echo "== watcher helpers (the real rd, sink_has_dv, vsvdb_now from lldv_watch.sh, on fake sysfs files)"
  W=$U/watch_fns.sh
  { sed -n '/^_CR=/p' $M/lldv_watch.sh; for _f in rd sink_has_dv vsvdb_now; do sed -n "/^$_f() {/,/^}/p" $M/lldv_watch.sh; done; } > $W
  . $W
  E=$U/sys
  mkdir -p $E
  printf '1\r\n' > $E/hpd_state
  printf '0' > $E/hdr_priority_mode
  printf '  1  \n' > $E/spaces
  check "rd value with CRLF"          "$(rd $E/hpd_state)" "1"
  check "rd value without newline"    "$(rd $E/hdr_priority_mode)" "0"
  check "rd value with spaces"        "$(rd $E/spaces)" "1"
  check "rd missing node is silent"   "$(rd $E/nonexistent 2>&1)" ""
  printf 'DolbyVision RX support list:\nVSVDB Version: V2\n' > $E/dv_cap2
  if sink_has_dv; then _r=yes; else _r=no; fi
  check "sink_has_dv with DV"         "$_r" yes
  printf "The Rx don't support DolbyVision\r\n" > $E/dv_cap2
  if sink_has_dv; then _r=yes; else _r=no; fi
  check "sink_has_dv without DV, CRLF" "$_r" no
  : > $E/dv_cap2
  if sink_has_dv; then _r=yes; else _r=no; fi
  check "sink_has_dv empty node"      "$_r" no
  rm -f $E/dv_cap2
  if sink_has_dv; then _r=yes; else _r=no; fi
  check "sink_has_dv missing node"    "$_r" no
  check "sink_has_dv missing node is silent" "$(sink_has_dv 2>&1)" ""
  printf 'DolbyVision RX support list:\r\nVSVDB: eb0146d000490348a15855a2\r\nmore\n' > $E/dv_cap2
  check "vsvdb_now with CRLF"         "$(vsvdb_now)" "eb0146d000490348a15855a2"
  printf "The Rx don't support DolbyVision\n" > $E/dv_cap2
  check "vsvdb_now without DV"        "$(vsvdb_now)" ""

  echo "== summary: PASS=$PASS FAIL=$FAIL"
} >> $O 2>&1
