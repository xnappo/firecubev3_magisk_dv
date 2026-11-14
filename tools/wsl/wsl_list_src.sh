#!/bin/bash
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# Lists the Amazon Fire TV Cube 3 source tarball into ~/fcsrc/toc.txt (runs in background-friendly way).
set -u
TARBALL=$ROOT/src/FireTVCubeGen3-7.7.1.4-20260624.tar.bz2
mkdir -p ~/fcsrc
cd ~/fcsrc || exit 1
rm -f toc.done toc.err
if command -v lbzip2 >/dev/null 2>&1; then
  lbzip2 -dc "$TARBALL" | tar -t > toc.txt 2> toc.err
else
  tar -tjf "$TARBALL" > toc.txt 2> toc.err
fi
echo done > toc.done
