#!/bin/bash
# Lists top-level (non-apps) members of the decompressed Amazon source tarball with sizes.
cd ~/fcsrc || exit 1
tar -tvf full.tar 2>/dev/null | grep -v ' apps/' | awk '{ print $3, $6 }' | grep -v '/.*/' | head -60
