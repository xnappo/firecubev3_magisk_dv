#!/usr/bin/env python3
"""Builds the Magisk module zip from module/ (Python 3.6+, no dependencies).

  python3 build_zip.py <module_dir> <out.zip>

Text files are written with LF line endings, entry names use forward slashes, and the executable bit is set on
scripts, so the zip behaves the same whichever OS built it.
"""
import os
import sys
import zipfile

EXEC = {"service.sh", "customize.sh", "uninstall.sh", "lldv_watch.sh", "action.sh", "lldv", "update-binary"}


def main():
    src, out = sys.argv[1], sys.argv[2]
    if os.path.exists(out):
        os.remove(out)
    names = []
    for root, _, files in os.walk(src):
        for f in files:
            full = os.path.join(root, f)
            names.append((os.path.relpath(full, src).replace(os.sep, "/"), full))
    names.sort()
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for arc, full in names:
            data = open(full, "rb").read()
            data = data.replace(b"\r\n", b"\n")
            info = zipfile.ZipInfo(arc, date_time=(2026, 11, 14, 0, 0, 0))
            mode = 0o755 if os.path.basename(arc) in EXEC else 0o644
            info.external_attr = (0o100000 | mode) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, data)
            print("%-48s %6d bytes  %o" % (arc, len(data), mode))
    print("wrote %s (%d bytes)" % (out, os.path.getsize(out)))


if __name__ == "__main__":
    main()
