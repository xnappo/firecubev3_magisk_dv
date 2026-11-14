#!/bin/bash
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# Extracts fireos.tar (nested kernel/platform sources) from the Amazon Cube 3 source tarball into ~/fcsrc/x.
set -u
TARBALL=$ROOT/src/FireTVCubeGen3-7.7.1.4-20260624.tar.bz2
mkdir -p ~/fcsrc/x
cd ~/fcsrc/x || exit 1
rm -f extract.done extract.err
tar -xjf "$TARBALL" fireos.tar 2> extract.err
echo "rc=$?" > extract.done
