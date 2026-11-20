#!/system/bin/sh
# Optional local web UI. Started by service.sh at boot when WEB=1; disabled by default.
# It runs as root on the LAN with NO authentication: anyone who can reach the port can change
# primaries/maxLum. That is deliberate for a trusted home network; do not expose it further.
MODDIR=${MODDIR:-${0%/*}}
LOG=${LLDV_LOG:-/data/local/tmp/lldv.log}
PIDF=/dev/lldv_httpd.pid
WEBLOG=/data/local/tmp/lldv_httpd.log

web_log() {
    echo "$(date '+%m-%d %H:%M:%S') web: $*" >> "$LOG"
}

. "$MODDIR/lldv_cfg.sh"
[ "${WEB:-0}" = "1" ] || exit 0

_port=${WEB_PORT:-18765}
case "$_port" in
    ''|*[!0-9]*) web_log "not started: WEB_PORT must be numeric"; exit 0 ;;
esac
if [ "$_port" -lt 1024 ] || [ "$_port" -gt 65535 ]; then
    web_log "not started: WEB_PORT must be 1024..65535"
    exit 0
fi
if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF" 2>/dev/null)" 2>/dev/null; then
    exit 0
fi
if [ ! -x "$MODDIR/www/cgi-bin/lldv.cgi" ]; then
    web_log "not started: $MODDIR/www/cgi-bin/lldv.cgi is missing"
    exit 0
fi

rm -f "$PIDF"
: > "$WEBLOG"
LLDV_MODDIR="$MODDIR" LLDV_OVERRIDE="$OVERRIDE" \
    nohup /data/adb/magisk/busybox httpd -f -p "$_port" -h "$MODDIR/www" -c "$MODDIR/www/httpd.conf" >> "$WEBLOG" 2>&1 &
_pid=$!
echo "$_pid" > "$PIDF"
sleep 1
if kill -0 "$_pid" 2>/dev/null; then
    web_log "listening on port $_port (no authentication; local network only)"
else
    web_log "ERROR httpd failed to start on port $_port (see $WEBLOG)"
    rm -f "$PIDF"
fi
