#!/bin/bash
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# Decodes the requested base VSVDB, the box's DV-position VSVDB and the old test template, and prints the maxLum table.
# Report -> captures/vsvdb_report.txt
W=$ROOT
T=$W/tools/dv_vsvdb.py
{
  echo "##### requested base block EB0146D0004903485798A953"
  python3 "$T" decode eb0146d0004903485798a953
  echo
  echo "##### box in DV position eb0146d000490b48a15855a2"
  python3 "$T" decode eb0146d000490b48a15855a2
  echo
  echo "##### old test template eb0146d0004d4f2a96381fbf"
  python3 "$T" decode eb0146d0004d4f2a96381fbf
  echo
  echo "##### selectable Target Max PQ codes"
  python3 "$T" table
} > "$W/captures/vsvdb_report.txt" 2>&1
