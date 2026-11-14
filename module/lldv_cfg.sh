#!/system/bin/sh
# lldv_cfg.sh - configuration shared by the watcher and the `lldv` command. Source it with MODDIR set, after
# sourcing lldv_lum.sh and lldv_gamut.sh (lldv_effective needs them).
#
# Layers, later ones win:   built-in defaults  <  $MODDIR/lldv.conf  <  /data/adb/lldv.conf
# /data/adb/lldv.conf is the user override file; `lldv set` writes only that file, and it survives module updates.
# Sourcing the override file executes it as shell, so it is only read when it is owned by root and not
# group/world writable.

OVERRIDE=${LLDV_OVERRIDE:-/data/adb/lldv.conf}
LLDV_CFG_WARN=

# built-in defaults
VSVDB=eb0146d0004903485798a953
MAXLUM=385
PRIMARIES=
POLL=2
SETTLE=3
HOLDOFF=15

# 0 when file $1 is owned by uid 0 and not group/world writable. Runs in a function so that `set --` cannot
# clobber the positional parameters of the script that sourced this file.
lldv_file_trusted() {
    set -- $(ls -ln "$1" 2>/dev/null)
    # $1 = mode string, $3 = uid
    _fp=$1
    [ "$3" = "0" ] && [ "${_fp:5:1}" != "w" ] && [ "${_fp:8:1}" != "w" ]
}

[ -f "$MODDIR/lldv.conf" ] && . "$MODDIR/lldv.conf"
if [ -f "$OVERRIDE" ]; then
    if lldv_file_trusted "$OVERRIDE"; then
        . "$OVERRIDE"
    else
        LLDV_CFG_WARN="ignoring $OVERRIDE: must be owned by root and not group/world writable ($(ls -ln "$OVERRIDE" 2>&1))"
    fi
fi

# a bad timing value must never turn the watcher into a busy loop
case "$POLL" in "" | *[!0-9]* | 0) POLL=2 ;; esac
case "$SETTLE" in "" | *[!0-9]*) SETTLE=3 ;; esac
case "$HOLDOFF" in "" | *[!0-9]*) HOLDOFF=15 ;; esac

# Computes VSVDB_EFF = base block, then the chosen colour primaries, then the requested MAXLUM.
# Empty/0 settings leave that part of the base block exactly as it is. A bad setting is ignored and described
# in CFG_ERRORS (empty when everything is fine).
lldv_effective() {
    VSVDB_EFF=$VSVDB
    CFG_ERRORS=
    if [ -n "$PRIMARIES" ]; then
        _e=$(lldv_apply_primaries "$VSVDB_EFF" "$PRIMARIES")
        case "$_e" in
            ERR:*) CFG_ERRORS="$CFG_ERRORS PRIMARIES=$PRIMARIES ignored: ${_e#ERR:};" ;;
            *) VSVDB_EFF=$_e ;;
        esac
    fi
    if [ -n "$MAXLUM" ] && [ "$MAXLUM" != "0" ]; then
        _e=$(lldv_apply_maxlum "$VSVDB_EFF" "$MAXLUM")
        case "$_e" in
            ERR:*) CFG_ERRORS="$CFG_ERRORS MAXLUM=$MAXLUM ignored: ${_e#ERR:};" ;;
            *) VSVDB_EFF=$_e ;;
        esac
    fi
}
