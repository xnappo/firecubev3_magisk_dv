#!/system/bin/sh
# Dev test, stage A (run as root on the Cube): NO load. Reads rawedid, saves the live EDID with a write of
# exactly 16 bytes (edid_store() always returns 16, so any other length makes the shell resend the remainder
# as new commands), and builds the patched EDID offline. Output -> /data/local/tmp/s16a_out.txt
E=/sys/class/amhdmitx/amhdmitx0
T=/data/local/tmp
O=$T/s16a_out.txt
DV=eb0146d0004d4f2a96381fbf
. $T/lldv_mod/lldv_edid.sh
: > $O
{
  echo "hpd=$(cat $E/hpd_state)  dv_cap2=$(head -1 $E/dv_cap2)"

  echo "== 1. rawedid -> binary"
  cat $E/rawedid | tr -d '\r\n ' > $T/box_raw.hex
  echo "rawedid hex chars: $(wc -c < $T/box_raw.hex)"
  xxd -r -p $T/box_raw.hex > $T/box_raw.bin
  echo "rawedid bin bytes: $(wc -c < $T/box_raw.bin)"

  echo "== 2. save with a 16-byte write"
  CMD='save bin /dev/ed'
  echo "command length: ${#CMD} (must be 16)"
  rm -f /dev/ed
  dmesg -c > /dev/null
  printf '%s' "$CMD" > $E/edid
  echo "write rc=$?"
  sleep 1
  ls -la /dev/ed
  if cmp -s /dev/ed $T/box_raw.bin; then echo "SAVE_MATCHES_RAWEDID"; else echo "SAVE_DIFFERS"; fi
  echo "-- kernel log after the save (a 'cmd format' line would mean a fragment was re-parsed):"
  dmesg | grep -e edid -e EDID -e hdmitx | tail -8

  echo "== 3. patch offline (no load)"
  lldv_patch_edid /dev/ed /dev/lldv_p $DV
  ls -la /dev/lldv_p
  echo "blocks: $(( $(wc -c < /dev/lldv_p) / 128 ))"
  cp /dev/ed /sdcard/Download/box_nondv_orig.bin
  cp /dev/lldv_p /sdcard/Download/box_nondv_plus_dv.bin
  echo DONE
} >> $O 2>&1
