#!/bin/bash
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# Prints the reference gamut encodings from tools/dv_vsvdb.py and decodes each resulting block.
# Report -> captures/gamut_report.txt
W=$ROOT
T=$W/tools/dv_vsvdb.py
{
  python3 "$T" gamut
  for p in bt709 bt2020 dcip3 ls12000; do
    h=$(python3 "$T" gamut | grep "^PRESET $p " | cut -d' ' -f3)
    echo
    echo "##### decode of $p -> $h"
    python3 "$T" decode "$h" | grep -e primaries -e "Target Max" -e Interface -e "10/12b"
  done
} > "$W/captures/gamut_report.txt" 2>&1
