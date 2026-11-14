#!/system/bin/sh
# lldv_guard.sh - boot-loop guard. Source this file, then call:
#
#   lldv_guard_boot <state-file> <boot-id> <limit>
#
# The watcher writes to a kernel sysfs node that panicked this device once during development (see lldv_watch.sh),
# so the module disables itself if the Cube keeps rebooting. A boot only counts once however often service.sh runs
# in it (identified by /proc/sys/kernel/random/boot_id); the watcher clears the state after 5 minutes of uptime.
#
# State file: "<boot-id> <count> <tripped>". Prints one of:
#   counted:N   a new boot, N unstable boots in a row (this one included)
#   repeat:N    service.sh ran again in a boot that was already counted
#   tripped:N   N >= limit; the caller must disable the module. The state stays marked as tripped, so a second
#               service.sh run in the same boot also gets 'tripped'; if the user re-enables the module later,
#               the first boot after that starts counting from 1 again.

LLDV_GUARD_STATE=/data/adb/lldv_boot_state
LLDV_GUARD_LIMIT=4

lldv_guard_boot() {
    _gs=$1
    _gb=$2
    _gt=$3
    _sid=""
    _n=0
    _tr=0
    [ -f "$_gs" ] && read _sid _n _tr < "$_gs"
    case "$_n" in "" | *[!0-9]*) _n=0 ;; esac
    case "$_tr" in 1) ;; *) _tr=0 ;; esac
    if [ "$_gb" = "$_sid" ]; then
        if [ "$_tr" = "1" ]; then
            echo "tripped:$_n"
            return 0
        fi
        _what=repeat
    else
        if [ "$_tr" = "1" ]; then
            _n=0
            _tr=0
        fi
        _n=$((_n + 1))
        _what=counted
    fi
    if [ "$_n" -ge "$_gt" ]; then
        _tr=1
        _what=tripped
    fi
    echo "$_gb $_n $_tr" > "$_gs"
    echo "$_what:$_n"
}
