#!/bin/bash
# Extracts platform.tar from the decompressed Amazon source tarball, then extracts only the Amlogic kernel tree
# (kernel/amlogic/...) into ~/fcsrc/plat. Writes ~/fcsrc/plat_toc.txt and ~/fcsrc/plat.done when finished.
set -u
cd ~/fcsrc || exit 1
rm -f plat.done plat.err
tar -xf full.tar -C ~/fcsrc/x platform.tar 2> plat.err
tar -tf ~/fcsrc/x/platform.tar > plat_toc.txt 2>> plat.err
mkdir -p ~/fcsrc/plat
tar -xf ~/fcsrc/x/platform.tar -C ~/fcsrc/plat --wildcards 'kernel/amlogic/*' 2>> plat.err
echo "rc=$?" > plat.done
