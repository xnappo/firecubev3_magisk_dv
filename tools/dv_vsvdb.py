#!/usr/bin/env python3
"""Dolby Vision VSVDB v2 helper for the Fire Cube 3 LLDV project (Python 3.6+, no dependencies).

  decode <hex>   decode a VSVDB with the SAME bit layout as _edid_parsingvendspec() in Amazon's hdmitx21 driver
                 (src/ref/hdmitx21_hdmi_tx_edid.c, the ver == 2 branch)
  table          print the 32 selectable Target Max PQ codes with their luminance, and the shell variable
                 LLDV_LUM_NITS used by module/lldv_lum.sh
  gamut          print the four colour-primary presets (BT709, BT2020, DCI-P3, LS12000 Native) as the parser
                 stores them, and the reference result of applying each to the default base block
  gamut <hex>    same, applied to the given VSVDB

Target Max PQ: byte 7 of the VSVDB (index 7 counting the 0xEB header as byte 0) bits 7:3 = a 5-bit code.
PQ12 = 2055 + 65 * code (the same mapping Amazon's parser and CoreELEC's decoder use: code 9 -> PQ 2640),
luminance = SMPTE ST 2084 EOTF of PQ12 / 4095.

CAVEAT: for code 9 this gives 371.6 cd/m^2, while CoreELEC's decoder labels the same PQ value 2640 as
"385 cd/m^2". The PQ code is what goes into the EDID and is unambiguous; the cd/m^2 labels here are my own
ST 2084 calculation and may differ from other tools' labels by a few percent.
"""
import sys

M1 = 2610 / 16384
M2 = 2523 / 4096 * 128
C1 = 3424 / 4096
C2 = 2413 / 4096 * 32
C3 = 2392 / 4096 * 32


def pq_to_nits(pq12):
    e = (pq12 / 4095.0) ** (1 / M2)
    return 10000.0 * (max(e - C1, 0.0) / (C2 - C3 * e)) ** (1 / M1)


def code_to_pq(code):
    return 2055 + 65 * code


def decode(h):
    d = bytes.fromhex(h)
    if len(d) < 12 or d[1] != 0x01 or d[2:5] != b"\x46\xd0\x00":
        raise SystemExit("not a Dolby VSVDB: " + h)
    out = []
    out.append("bytes            : %d (header 0x%02x -> length field %d)" % (len(d), d[0], d[0] & 0x1F))
    out.append("version          : %d" % ((d[5] >> 5) & 7))
    out.append("DM version       : %d" % ((d[5] >> 2) & 7))
    out.append("YCbCr 4:2:2 12bit: %d" % (d[5] & 1))
    out.append("backlight control: %d" % ((d[5] >> 1) & 1))
    out.append("global dimming   : %d" % ((d[6] >> 2) & 1))
    out.append("backlt_min_luma  : %d" % (d[6] & 3))
    out.append("Target Min PQ    : code %d (formula not verified, left as is)" % (d[6] >> 3))
    iface = d[7] & 3
    out.append("Interface        : %d  (%s)" % (iface, {0: "low-latency only", 1: "low-latency + ?",
                                                        2: "standard + low-latency",
                                                        3: "standard + low-latency, 10/12 bit 4:4:4"}[iface]))
    tmax = d[7] >> 3
    out.append("Target Max PQ    : code %d -> PQ12 %d -> %.1f cd/m^2" % (tmax, code_to_pq(tmax),
                                                                      pq_to_nits(code_to_pq(tmax))))
    out.append("10/12b 4:4:4     : %d" % (((d[8] & 1) << 1) | (d[9] & 1)))
    prim = {
        "Rx,Ry": ((0xA0 | (d[10] >> 3)) / 256, (0x40 | (d[11] >> 3)) / 256),
        "Gx,Gy": ((0x00 | (d[8] >> 1)) / 256, (0x80 | (d[9] >> 1)) / 256),
        "Bx,By": ((0x20 | (d[10] & 7)) / 256, (0x08 | (d[11] & 7)) / 256),
    }
    for k, (x, y) in prim.items():
        out.append("primaries %s : %.8f, %.8f" % (k, x, y))
    return "\n".join(out)


def table():
    rows = []
    nits = []
    for c in range(32):
        n = pq_to_nits(code_to_pq(c))
        nits.append(int(round(n)))
        rows.append("code %2d  PQ12 %4d  %7.1f cd/m^2" % (c, code_to_pq(c), n))
    rows.append("")
    rows.append('LLDV_LUM_NITS="%s"' % " ".join(str(n) for n in nits))
    return "\n".join(rows)


# ---- colour primaries -------------------------------------------------------------------------------------
# Presets supplied by the project owner (the table used for his EZCOO tool). Order: Rx Ry Gx Gy Bx By.
PRESETS = {
    "bt709": (0.6400, 0.3300, 0.3000, 0.6000, 0.1500, 0.0600),
    "bt2020": (0.7080, 0.2920, 0.1700, 0.7970, 0.1310, 0.0460),
    "dcip3": (0.6800, 0.3200, 0.2650, 0.6900, 0.1500, 0.0600),
    "ls12000": (0.6670, 0.3310, 0.3140, 0.6720, 0.1480, 0.0420),
}
ORDER = ["bt709", "bt2020", "dcip3", "ls12000"]
LABELS = {"bt709": "BT709", "bt2020": "BT2020", "dcip3": "DCI-P3", "ls12000": "LS12000 Native"}
NAMES = ["Rx", "Ry", "Gx", "Gy", "Bx", "By"]
# Reachable /256 code range per coordinate in a v2 VSVDB (fixed high bits in _edid_parsingvendspec()):
#   Rx = 0xA0|b10>>3  Ry = 0x40|b11>>3  Gx = b8>>1  Gy = 0x80|b9>>1  Bx = 0x20|b10&7  By = 0x08|b11&7
RANGE = [(160, 191), (64, 95), (0, 127), (128, 255), (32, 39), (8, 15)]


def preset_codes(name):
    """/256 code for each coordinate, rounded DOWN (floor).

    Floor, not nearest: it reproduces a known-good LS12000 calibration EDID bit for bit
    (captures/ls12000_known_good.txt), and the default base block's primaries are BT2020 floored.
    Integer arithmetic on the 4-decimal values, so float error cannot push e.g. 0.6720*256 = 172.032 across a step.
    """
    return [int(round(v * 10000)) * 256 // 10000 for v in PRESETS[name]]


def primary_codes(d):
    """The six /256 codes the parser derives from VSVDB bytes (d[0] = 0xEB header)."""
    return [0xA0 | (d[10] >> 3), 0x40 | (d[11] >> 3), d[8] >> 1, 0x80 | (d[9] >> 1), 0x20 | (d[10] & 7),
            0x08 | (d[11] & 7)]


def encode_primaries(h, name):
    """Reference implementation of module/lldv_gamut.sh: replace the primaries, keep every other bit."""
    d = bytearray(bytes.fromhex(h))
    if d[5] >> 5 != 2:
        raise SystemExit("only VSVDB version 2 is supported")
    rx, ry, gx, gy, bx, by = codes = preset_codes(name)
    for c, (lo, hi), n in zip(codes, RANGE, NAMES):
        if not lo <= c <= hi:
            raise SystemExit("%s code %d outside the encodable range %d..%d" % (n, c, lo, hi))
    d[8] = (gx << 1) | (d[8] & 1)
    d[9] = ((gy & 127) << 1) | (d[9] & 1)
    d[10] = ((rx & 31) << 3) | (bx & 7)
    d[11] = ((ry & 31) << 3) | (by & 7)
    if primary_codes(d) != codes:
        raise SystemExit("internal error: encode/decode mismatch")
    return d.hex()


def gamut(base):
    out = []
    out.append("base block: " + base)
    out.append("")
    out.append("%-15s %s" % ("preset", "  ".join("%-17s" % n for n in NAMES)))
    for p in ORDER:
        cells = []
        for v, c, (lo, hi) in zip(PRESETS[p], preset_codes(p), RANGE):
            cells.append("%.4f>%3d=%.4f%s" % (v, c, c / 256, "" if lo <= c <= hi else "!"))
        out.append("%-15s %s" % (LABELS[p], "  ".join(cells)))
    out.append("(request > code = stored value; '!' would mean outside the encodable range)")
    out.append("")
    for p in ORDER:
        out.append("PRESET %s %s" % (p, encode_primaries(base, p)))
    out.append("")
    out.append("decoded base block primaries (codes): %s" % primary_codes(bytes.fromhex(base)))
    return "\n".join(out)


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "decode":
        print(decode(sys.argv[2].lower()))
    elif len(sys.argv) >= 2 and sys.argv[1] == "table":
        print(table())
    elif len(sys.argv) >= 2 and sys.argv[1] == "gamut":
        print(gamut(sys.argv[2].lower() if len(sys.argv) >= 3 else "eb0146d0004903485798a953"))
    else:
        print(__doc__)
