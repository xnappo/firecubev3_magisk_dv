#!/system/bin/sh
# lldv_gamut.sh - colour-primary presets for the Dolby Vision VSVDB. Source this file, then call:
#
#   lldv_apply_primaries <vsvdb-hex> <preset>
#
# Presets (name matching ignores case, spaces, dashes and dots):
#   BT709            Rx 0.6400 Ry 0.3300  Gx 0.3000 Gy 0.6000  Bx 0.1500 By 0.0600
#   BT2020           Rx 0.7080 Ry 0.2920  Gx 0.1700 Gy 0.7970  Bx 0.1310 By 0.0460
#   DCI-P3           Rx 0.6800 Ry 0.3200  Gx 0.2650 Gy 0.6900  Bx 0.1500 By 0.0600     (also: P3)
#   LS12000 Native   Rx 0.6670 Ry 0.3310  Gx 0.3140 Gy 0.6720  Bx 0.1480 By 0.0420     (also: LS12000)
#
# Prints the new VSVDB (lowercase hex), or ERR:<reason> (exit status 1).
#
# Encoding (VSVDB v2, the layout hdmitx21's _edid_parsingvendspec() decodes; byte 0 is the 0xEB header). Each
# coordinate is a /256 code with some high bits fixed by the format, which limits its range:
#   byte 8  = Gx[6:0]<<1                 | (kept: bit 0 = 10/12-bit 4:4:4 flag)         Gx 0.000..0.496
#   byte 9  = Gy[6:0]<<1                 | (kept: bit 0 = 10/12-bit 4:4:4 flag)         Gy 0.500..0.996
#   byte 10 = Rx[4:0]<<3 | Bx[2:0]                                                      Rx 0.625..0.746  Bx 0.125..0.152
#   byte 11 = Ry[4:0]<<3 | By[2:0]                                                      Ry 0.250..0.371  By 0.031..0.058
# The /256 codes below are rounded DOWN (floor), not to the nearest step: that reproduces a known-good LS12000
# calibration EDID bit for bit (captures/ls12000_known_good.txt), and the default base block's primaries are BT2020
# floored too. They are generated and cross-checked by tools/dv_vsvdb.py (`gamut`).
# The v2 block has no white point field.
#
# Whether the Dolby Vision engine (dovi.ko, closed source) uses these primaries is NOT verified.

# Prints the canonical preset name (BT709, BT2020, DCI-P3 or LS12000) for a user-supplied name, or ERR:<reason>.
lldv_primaries_canon() {
    _cn=$(echo "$1" | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9')
    case "$_cn" in
        bt709) echo BT709 ;;
        bt2020) echo BT2020 ;;
        dcip3 | p3) echo DCI-P3 ;;
        ls12000 | ls12000native) echo LS12000 ;;
        *) echo "ERR:unknown primaries preset '$1' (use BT709, BT2020, DCI-P3 or LS12000)"; return 1 ;;
    esac
}

lldv_apply_primaries() {
    _pv=$1
    _pn=$(echo "$2" | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9')

    # Rx Ry Gx Gy Bx By as /256 codes
    case "$_pn" in
        bt709) set -- 163 84 76 153 38 15 ;;
        bt2020) set -- 181 74 43 204 33 11 ;;
        dcip3 | p3) set -- 174 81 67 176 38 15 ;;
        ls12000 | ls12000native) set -- 170 84 80 172 37 10 ;;
        *)
            echo "ERR:unknown primaries preset '$2' (use BT709, BT2020, DCI-P3 or LS12000)"
            return 1
            ;;
    esac
    _rx=$1
    _ry=$2
    _gx=$3
    _gy=$4
    _bx=$5
    _by=$6

    case "$_pv" in
        *[!0-9a-f]*) echo "ERR:vsvdb is not lowercase hex"; return 1 ;;
    esac
    if [ "${#_pv}" -lt 24 ] || [ "${_pv:2:8}" != "0146d000" ]; then
        echo "ERR:not a Dolby VSVDB"
        return 1
    fi
    _b5=$((0x${_pv:10:2}))
    if [ $((_b5 >> 5)) -ne 2 ]; then
        echo "ERR:primaries are only supported for VSVDB version 2"
        return 1
    fi

    _b8=$((0x${_pv:16:2}))
    _b9=$((0x${_pv:18:2}))
    _n8=$(( (_gx << 1) | (_b8 & 1) ))
    _n9=$(( ((_gy & 127) << 1) | (_b9 & 1) ))
    _n10=$(( ((_rx & 31) << 3) | (_bx & 7) ))
    _n11=$(( ((_ry & 31) << 3) | (_by & 7) ))
    printf '%s%02x%02x%02x%02x%s\n' "${_pv:0:16}" $_n8 $_n9 $_n10 $_n11 "${_pv:24}"
}
