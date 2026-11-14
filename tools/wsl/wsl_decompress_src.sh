#!/bin/bash
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# Decompresses the Amazon Cube 3 source tarball once into ~/fcsrc/full.tar so later listing/extraction is fast.
set -u
TARBALL=$ROOT/src/FireTVCubeGen3-7.7.1.4-20260624.tar.bz2
mkdir -p ~/fcsrc
cd ~/fcsrc || exit 1
rm -f full.done full.err
bzip2 -dc "$TARBALL" > full.tar 2> full.err
echo "rc=$?" > full.done
