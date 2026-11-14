#!/usr/bin/env python3
"""EDID helper for the Fire Cube 3 LLDV project (Python 3.6+, no dependencies).

Commands:
  info     <in.bin>                         decode base block + CTA data blocks
  strip-dv <in.bin> <out.bin>               remove every Dolby VSVDB from the CTA blocks (simulates a non-DV sink)
  add-dv   <in.bin> <out.bin> [hex]         append a new CTA block holding only the DV VSVDB and bump the extension count
                                            (hex defaults to the V2 low-latency template below)
"""
import sys

DV_OUI = bytes([0x46, 0xD0, 0x00])
# Header 0xEB = tag 7 (extended) | length 11, ext tag 0x01 (vendor specific video DB), OUI 46 D0 00, 7 payload bytes.
# Payload is the V2 / YCbCr422-12bit / low-latency block captured from the test TV (VSVDB eb0146d0004d4f2a96381fbf).
DEFAULT_DV = bytes.fromhex("eb0146d0004d4f2a96381fbf")

TAGS = {1: "Audio", 2: "Video", 3: "Vendor", 4: "Speaker", 5: "VESA DTC", 7: "Extended"}
EXT_TAGS = {0: "Video Capability", 1: "Vendor Video", 5: "Colorimetry", 6: "HDR Static Metadata",
            7: "HDR Dynamic Metadata", 13: "Video Format Preference", 14: "YCbCr420 VDB", 15: "YCbCr420 CMDB",
            18: "HDMI Audio", 19: "Room Config", 32: "InfoFrame DB"}


def checksum_fix(block):
    block[127] = (-sum(block[:127])) & 0xFF


def data_blocks(block):
    """Yield (offset, length_incl_header, tag, ext_tag) for the CTA data block collection."""
    d = block[2]
    off = 4
    while off < d and off < 127:
        tag = block[off] >> 5
        ln = block[off] & 0x1F
        ext = block[off + 1] if tag == 7 and ln > 0 else None
        yield off, ln + 1, tag, ext
        off += ln + 1


def is_dv(block, off, ln, tag, ext):
    return tag == 7 and ext == 1 and block[off + 2:off + 5] == DV_OUI


def info(data):
    print("length=%d blocks=%d" % (len(data), len(data) // 128))
    print("ext count (0x7e)=%d  blk0 checksum ok=%s" % (data[0x7E], sum(data[:128]) & 0xFF == 0))
    for b in range(1, len(data) // 128):
        blk = data[b * 128:(b + 1) * 128]
        print("block %d: tag=%02x rev=%02x D=%d byte3=%02x checksum ok=%s free=%d" % (
            b, blk[0], blk[1], blk[2], blk[3], sum(blk) & 0xFF == 0,
            127 - blk[2] - sum(1 for i in range(blk[2], 127, 18) if any(blk[i:i + 18]) and i + 18 <= 127) * 18))
        if blk[0] != 2:
            continue
        for off, ln, tag, ext in data_blocks(blk):
            name = TAGS.get(tag, str(tag))
            if tag == 7:
                name += "/" + EXT_TAGS.get(ext, "ext%s" % ext)
            extra = "  <== DOLBY VSVDB" if is_dv(blk, off, ln, tag, ext) else ""
            print("  @%3d len=%2d %-28s %s%s" % (off, ln, name, blk[off:off + ln].hex(), extra))
        pad = blk[blk[2]:127]
        print("  trailing bytes after data blocks: %d (non-zero: %d)" % (len(pad), sum(1 for x in pad if x)))


def strip_dv(data):
    out = bytearray(data)
    for b in range(1, len(out) // 128):
        blk = bytearray(out[b * 128:(b + 1) * 128])
        if blk[0] != 2:
            continue
        while True:
            hit = [(o, l) for o, l, t, e in data_blocks(blk) if is_dv(blk, o, l, t, e)]
            if not hit:
                break
            off, ln = hit[0]
            d = blk[2]
            # shift everything after the block (rest of data blocks + DTDs) left, zero-pad, fix D
            tail = blk[off + ln:127]
            blk[off:127] = tail + bytes(ln)
            blk[2] = d - ln
        checksum_fix(blk)
        out[b * 128:(b + 1) * 128] = blk
    return bytes(out)


def add_dv(data, dv):
    out = bytearray(data)
    if out[0x7E] + 1 >= 8:
        raise SystemExit("EDID already has the maximum number of blocks")
    first_cta = next((b for b in range(1, len(out) // 128) if out[b * 128] == 2), None)
    byte3 = (out[first_cta * 128 + 3] & 0xF0) if first_cta else 0x70  # copy capability flags, 0 DTDs
    blk = bytearray(128)
    blk[0], blk[1] = 0x02, 0x03
    blk[2] = 4 + len(dv)
    blk[3] = byte3
    blk[4:4 + len(dv)] = dv
    checksum_fix(blk)
    nblocks = len(out) // 128
    out += blk
    out[0x7E] = nblocks  # existing extension count + 1 (nblocks already includes base block)
    checksum_fix_base = bytearray(out[:128])
    checksum_fix(checksum_fix_base)
    out[:128] = checksum_fix_base
    return bytes(out)


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 1
    cmd = argv[1]
    data = open(argv[2], "rb").read()
    if cmd == "info":
        info(data)
    elif cmd == "strip-dv":
        res = strip_dv(data)
        open(argv[3], "wb").write(res)
        info(res)
    elif cmd == "add-dv":
        dv = bytes.fromhex(argv[4]) if len(argv) > 4 else DEFAULT_DV
        res = add_dv(data, dv)
        open(argv[3], "wb").write(res)
        info(res)
    else:
        print(__doc__)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
