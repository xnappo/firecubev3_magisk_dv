#!/bin/bash
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# Builds the test EDIDs from captures/edid_orig.bin and writes a report to captures/edid_report.txt
W=$ROOT
C=$W/captures
T=$W/tools/edid_tool.py
{
  echo "##### ORIGINAL"
  python3 "$T" info "$C/edid_orig.bin"
  echo
  echo "##### STRIP-DV  -> edid_nodv.bin (2 blocks, simulates non-DV sink)"
  python3 "$T" strip-dv "$C/edid_orig.bin" "$C/edid_nodv.bin"
  echo
  echo "##### ADD-DV on nodv -> edid_nodv_plus_dv3.bin (3 blocks)"
  python3 "$T" add-dv "$C/edid_nodv.bin" "$C/edid_nodv_plus_dv3.bin"
  echo
  echo "##### ADD-DV on original (already has DV) -> edid_orig_plus_dv3.bin (3 blocks)"
  python3 "$T" add-dv "$C/edid_orig.bin" "$C/edid_orig_plus_dv3.bin"
} > "$C/edid_report.txt" 2>&1
ls -la "$C" >> "$C/edid_report.txt"
