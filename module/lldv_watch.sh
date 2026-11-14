#!/system/bin/sh
# lldv_watch.sh - keeps a Dolby Vision VSVDB present in the Fire TV Cube 3's view of the connected display.
#
# State based, not event based: hpd_state does not change on a standby wake (the kernel re-reads the EDID with
# HPD still high), so every POLL seconds this checks whether the sink currently reports Dolby Vision and, if not,
# injects the VSVDB. Real DV displays are left alone. The settings (lldv.conf, /data/adb/lldv.conf) are re-read on
# every pass, so a change made with the `lldv` command is applied within seconds, without a reboot.
#
# SAFETY - the kernel's edid_store() (hdmi_tx_main.c) always returns 16 whatever the write length, so a command
# longer or shorter than 16 bytes makes the shell resend the remainder as NEW commands; after a few dozen such
# writes the Cube panicked in edid_store/kstrdup (captures/pstore_dmesg.txt). Every write to the edid node here is
# therefore EXACTLY 16 bytes with no newline, and the files live at fixed short paths on the /dev tmpfs:
#     save bin /dev/ed     live EDID -> /dev/ed
#     load /dev/lldv_p     load the patched EDID
#     load /dev/lldv_o     load the original EDID again (restore)
#
# Usage: sh lldv_watch.sh [--once]      (--once = a single check/inject pass, no loop; used by the dev tests)

MODDIR=${MODDIR:-${0%/*}}
E=/sys/class/amhdmitx/amhdmitx0
LOG=${LLDV_LOG:-/data/local/tmp/lldv.log}
PIDF=/dev/lldv_watch.pid

SAVED=/dev/ed
PATCHED=/dev/lldv_p
ORIG=/dev/lldv_o
CMD_SAVE='save bin /dev/ed'
CMD_LOAD_PATCHED='load /dev/lldv_p'
CMD_LOAD_ORIG='load /dev/lldv_o'

. "$MODDIR/lldv_edid.sh"
. "$MODDIR/lldv_lum.sh"
. "$MODDIR/lldv_gamut.sh"
. "$MODDIR/lldv_guard.sh"

log() {
    echo "$(date '+%m-%d %H:%M:%S') $*" >> "$LOG"
    if [ "$(wc -c < "$LOG")" -gt 102400 ]; then
        tail -n 200 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
    fi
}

# (Re)reads the settings and computes VSVDB_EFF; logs setting problems once per distinct problem.
reload_cfg() {
    . "$MODDIR/lldv_cfg.sh"
    lldv_effective
    _msg="$LLDV_CFG_WARN$CFG_ERRORS"
    if [ "$_msg" != "$LAST_CFG_MSG" ]; then
        LAST_CFG_MSG=$_msg
        [ -n "$_msg" ] && log "WARN settings:$_msg"
    fi
}

# Writes one command to the kernel's edid node. Refuses anything that is not exactly 16 bytes.
edid_cmd() {
    if [ "${#1}" -ne 16 ]; then
        log "BUG refusing edid command of ${#1} bytes: $1"
        return 1
    fi
    printf '%s' "$1" > "$E/edid"
}

# Value of a sysfs node with CR/LF/space stripped
rd() {
    _v=$(cat "$1" 2>/dev/null | tr -d '\r\n ')
    echo "$_v"
}

# 0 when the sink reports Dolby Vision (real or injected). dv_cap2 is the unmasked copy of dv_cap.
sink_has_dv() {
    _l=$(head -1 "$E/dv_cap2" 2>/dev/null)
    case "$_l" in
        "" | *"don't support"*) return 1 ;;
    esac
    return 0
}

# The VSVDB (lowercase hex) the kernel currently reports, empty if none
vsvdb_now() {
    _vl=$(grep -m1 'VSVDB:' "$E/dv_cap2" 2>/dev/null)
    _vl=${_vl#*VSVDB: }
    case "$_vl" in *VSVDB*) _vl= ;; esac
    echo "$_vl" | tr -d '\r\n '
}

# md5 of the EDID the kernel currently holds
edid_sig() {
    _m=$(cat "$E/rawedid" 2>/dev/null | md5sum)
    echo "${_m%% *}"
}

# 0 when the kernel holds a plausible EDID (starts with the 8-byte header, at least two blocks)
have_edid() {
    _r=$(cat "$E/rawedid" 2>/dev/null | tr -d '\r\n ')
    [ "${#_r}" -ge 512 ] && [ "${_r:0:16}" = "00ffffffffffff00" ]
}

# Android only re-reads the display capabilities on a plug event (fake_plug keeps the loaded EDID).
plug_cycle() {
    echo 0 > "$E/fake_plug"
    sleep 2
    echo 1 > "$E/fake_plug"
}

# Patches the EDID file $1 with VSVDB_EFF, loads it, checks the kernel now reports DV, cycles the plug.
# $2 = what happened, for the log. On failure the display's original EDID is loaded again.
do_inject() {
    rm -f "$PATCHED"
    _res=$(lldv_patch_edid "$1" "$PATCHED" "$VSVDB_EFF")
    case "$_res" in
        OK) ;;
        PRESENT)
            log "EDID already contains a Dolby VSVDB but dv_cap2 does not report it; leaving it alone"
            return 1
            ;;
        *)
            log "ERROR cannot patch EDID: $_res"
            return 1
            ;;
    esac

    edid_cmd "$CMD_LOAD_PATCHED" || return 1
    sleep 2
    if ! sink_has_dv; then
        log "ERROR loaded EDID but the kernel still reports no DV; restoring the original EDID"
        edid_cmd "$CMD_LOAD_ORIG"
        return 1
    fi

    plug_cycle
    INJECTED=$VSVDB_EFF
    log "$2 Dolby VSVDB $VSVDB_EFF (EDID now $(wc -c < "$PATCHED") bytes, kernel reports $(vsvdb_now)) and cycled fake_plug"
    return 0
}

# The display reported no DV: save its EDID (kept as the original) and inject
inject_new() {
    # dump_edid_data() opens with O_CREAT but no O_TRUNC, so a stale longer file would leave trailing bytes
    rm -f "$SAVED" "$ORIG"
    edid_cmd "$CMD_SAVE" || return 1
    sleep 1
    if [ ! -s "$SAVED" ]; then
        log "ERROR save of the live EDID failed"
        return 1
    fi
    cp "$SAVED" "$ORIG"
    do_inject "$SAVED" injected
}

# Settings changed while our own block is active: patch the saved original with the new block
inject_changed() {
    if [ ! -s "$ORIG" ]; then
        log "ERROR no saved original EDID, cannot apply the new settings until the next hotplug"
        return 1
    fi
    do_inject "$ORIG" "settings changed, re-injected"
}

# One check. Returns 0 when it injected, 1 otherwise.
check_once() {
    reload_cfg
    [ "$(rd "$E/hpd_state")" = "1" ] || return 1
    # hdr_priority_mode != 0 deliberately hides DV (dv_cap and dv_cap2); respect it
    [ "$(rd "$E/hdr_priority_mode")" = "0" ] || return 1

    if sink_has_dv; then
        # Only ever touch a DV block that we injected ourselves (reported VSVDB == what we injected), and
        # only once per distinct settings value.
        if [ -n "$INJECTED" ] && [ "$VSVDB_EFF" != "$INJECTED" ] && [ "$(vsvdb_now)" = "$INJECTED" ] &&
           [ "$VSVDB_EFF" != "$LAST_CHANGE_FAIL" ]; then
            log "settings changed: injected $INJECTED -> wanted $VSVDB_EFF"
            if inject_changed; then
                LAST_CHANGE_FAIL=""
            else
                LAST_CHANGE_FAIL=$VSVDB_EFF
            fi
            sleep "$HOLDOFF"
        fi
        return 1
    fi
    have_edid || return 1

    _sig=$(edid_sig)
    # one attempt per EDID and settings: if injecting failed for this exact case, do not hammer the kernel again
    [ "$_sig|$VSVDB_EFF" = "$LAST_FAIL" ] && return 1
    # let a hotplug / EDID re-read finish before touching the edid node
    sleep "$SETTLE"
    [ "$(rd "$E/hpd_state")" = "1" ] || return 1
    [ "$(edid_sig)" = "$_sig" ] || return 1
    sink_has_dv && return 1

    log "sink reports no Dolby Vision (edid $_sig)"
    if inject_new; then
        LAST_FAIL=""
        LAST_CHANGE_FAIL=""
    else
        LAST_FAIL="$_sig|$VSVDB_EFF"
    fi
    # hold off before the next attempt whatever happened, so a misbehaving sink cannot cause a tight loop
    sleep "$HOLDOFF"
    [ "$LAST_FAIL" = "" ]
}

# The boot-loop guard state is cleared once the Cube has been up for 5 minutes
guard_clear_if_stable() {
    [ "$GUARD_CLEARED" = "1" ] && return 0
    read _up _ < /proc/uptime
    _up=${_up%.*}
    case "$_up" in "" | *[!0-9]*) return 0 ;; esac
    if [ "$_up" -ge 300 ]; then
        rm -f "$LLDV_GUARD_STATE"
        GUARD_CLEARED=1
        log "boot guard: stable for 5 minutes, counter cleared"
    fi
}

LAST_FAIL=""
LAST_CHANGE_FAIL=""
LAST_CFG_MSG=""
INJECTED=""
GUARD_CLEARED=0

if [ "$1" = "--once" ]; then
    check_once
    exit $?
fi

if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
    exit 0
fi
echo $$ > "$PIDF"

reload_cfg
log "watcher started (pid $$, poll ${POLL}s, settle ${SETTLE}s, holdoff ${HOLDOFF}s, base vsvdb $VSVDB, primaries ${PRIMARIES:-base}, maxlum ${MAXLUM:-unset}, effective vsvdb $VSVDB_EFF)"
while true; do
    check_once
    guard_clear_if_stable
    sleep "$POLL"
done
