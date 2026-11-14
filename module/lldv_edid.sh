#!/system/bin/sh
# lldv_edid.sh - EDID patching helpers for the Fire Cube 3 LLDV module. Source this file, then call:
#
#   lldv_patch_edid <in.bin> <out.bin> <vsvdb-hex>
#
# Appends one CTA extension block that holds only the Dolby Vision VSVDB, leaving every original block untouched,
# and bumps the extension count (and the HF-EEODB count if the sink uses one). Prints exactly one word:
#   OK              out.bin written
#   PRESENT         the EDID already carries a Dolby Vision VSVDB - nothing to do
#   ERR:<reason>    in.bin cannot be patched
#
# Why a new block: many sinks have a "full" CTA block with no room for the 12-byte VSVDB. hdmitx21_edid_parse()
# parses every CTA block (up to 8), so a separate block always works.
#
# Pure sh + od + xxd -r + tr + wc. An awk version was tried first, but Android's awk (one-true-awk 20121220)
# aborted with "illegal jump type 339" (captures/test10_bisect.txt shows it failing on an array subscript built
# from substr(); the remaining failure was not isolated), so awk is deliberately not used.
# Needs mksh features: ${var:off:len}, $((0x..)) arithmetic, printf with '%*s'.

# NOTE (probed on the device, see captures/test12_probe.txt and test13_hex.txt): mksh R56 supports ${v:off:len}
# and $((0x..)) fine, but this toybox's `xxd -p | tr -d '\n'` leaves the newlines in (a 256-byte EDID came out as
# 520 characters), which shifted every offset. `od -An -v -tx1 | tr -d ' \012'` gives the exact hex string.

# byte value (decimal) at byte offset $2 of hex string $1
_lldv_byte() {
    _bv=$1
    echo $((0x${_bv:$(($2 * 2)):2}))
}

# Sum (mod 256) of the first $2 bytes of hex string $1
_lldv_sum() {
    _sv=$1
    _s=0
    _i=0
    while [ $_i -lt $2 ]; do
        _s=$((_s + 0x${_sv:$((_i * 2)):2}))
        _i=$((_i + 1))
    done
    echo $((_s % 256))
}

# Replaces the final byte (checksum) of a 128-byte block hex string with the correct value
_lldv_fix_block() {
    _body=${1:0:254}
    _sum=$(_lldv_sum "$_body" 127)
    printf '%s%02x' "$_body" $(((256 - _sum) % 256))
}

lldv_patch_edid() {
    _in=$1
    _out=$2
    _dv=$3

    [ -f "$_in" ] || { echo "ERR:no input file"; return 1; }
    _size=$(wc -c < "$_in")
    if [ "$_size" -lt 256 ] || [ $((_size % 128)) -ne 0 ]; then
        echo "ERR:length $_size"
        return 1
    fi
    _nblk=$((_size / 128))
    if [ "$_nblk" -ge 8 ]; then
        echo "ERR:EDID already has 8 blocks"
        return 1
    fi

    _dvlen=$((${#_dv} / 2))
    case "$_dv" in
        *[!0-9a-f]*) echo "ERR:vsvdb is not lowercase hex"; return 1 ;;
    esac
    if [ "$_dvlen" -lt 12 ] || [ "$_dvlen" -gt 28 ] || [ "${_dv:2:8}" != "0146d000" ] ||
       [ $((0x${_dv:0:2})) -ne $((224 + _dvlen - 1)) ]; then
        echo "ERR:vsvdb is not a Dolby VSVDB"
        return 1
    fi

    _hex=$(od -An -v -tx1 "$_in" | tr -d ' \012')
    if [ "${#_hex}" -ne $((_size * 2)) ]; then
        echo "ERR:hex conversion length ${#_hex}"
        return 1
    fi

    # base block: header + checksum
    if [ "${_hex:0:16}" != "00ffffffffffff00" ]; then
        echo "ERR:bad EDID header"
        return 1
    fi
    if [ "$(_lldv_sum "${_hex:0:256}" 128)" != "0" ]; then
        echo "ERR:base block checksum"
        return 1
    fi

    # walk the CTA blocks: remember the first one, look for any existing Dolby VSVDB
    _cta=0
    _k=1
    while [ $_k -lt $_nblk ]; do
        _blk=${_hex:$((_k * 256)):256}
        if [ "$(_lldv_byte "$_blk" 0)" = "2" ]; then
            [ $_cta -eq 0 ] && _cta=$_k
            _d=$(_lldv_byte "$_blk" 2)
            [ "$_d" -gt 127 ] && _d=127
            _off=4
            while [ $_off -lt $_d ]; do
                _hdr=$(_lldv_byte "$_blk" $_off)
                _len=$((_hdr & 31))
                if [ $((_hdr >> 5)) -eq 7 ] && [ $_len -ge 4 ] && [ "${_blk:$(((_off + 1) * 2)):8}" = "0146d000" ]; then
                    echo "PRESENT"
                    return 0
                fi
                _off=$((_off + _len + 1))
            done
        fi
        _k=$((_k + 1))
    done
    if [ $_cta -eq 0 ]; then
        echo "ERR:no CTA block"
        return 1
    fi

    # new CTA block: tag 02, rev 03, D = 4 + len(vsvdb), flags copied from the first CTA block, 0 DTDs
    _cblk=${_hex:$((_cta * 256)):256}
    _flags=$(( $(_lldv_byte "$_cblk" 3) & 240 ))
    _pad=$((127 - 4 - _dvlen))
    _zeros=$(printf '%*s' $((_pad * 2)) '' | tr ' ' '0')
    _new=$(printf '0203%02x%02x%s%s00' $((4 + _dvlen)) $_flags "$_dv" "$_zeros")
    _new=$(_lldv_fix_block "$_new")

    # extension count: base byte 126. With an HF-EEODB (e2 78 <count> as the first data block of the first
    # extension) the parser takes the count from there when byte 126 is 1.
    _base=${_hex:0:256}
    _ext1=${_hex:256:256}
    if [ "$(_lldv_byte "$_base" 126)" = "1" ] && [ "${_ext1:8:4}" = "e278" ]; then
        _ext1="${_ext1:0:12}$(printf '%02x' "$_nblk")${_ext1:14}"
        _ext1=$(_lldv_fix_block "$_ext1")
    else
        _base="${_base:0:252}$(printf '%02x' "$_nblk")${_base:254}"
    fi
    _base=$(_lldv_fix_block "$_base")

    {
        printf '%s' "$_base"
        printf '%s' "$_ext1"
        printf '%s' "${_hex:512}"
        printf '%s' "$_new"
    } | xxd -r -p > "$_out"

    echo "OK"
    return 0
}
