#!/system/bin/sh
# Optional local web UI. Started by service.sh at boot when WEB=1; disabled by default.
# The web UI is a LAN service running as root, so a non-empty, shell-safe WEB_PASS is mandatory.
MODDIR=${MODDIR:-${0%/*}}
LOG=${LLDV_LOG:-/data/local/tmp/lldv.log}
PIDF=/dev/lldv_httpd.pid
CONF=/dev/lldv_httpd.conf
WEBLOG=/data/local/tmp/lldv_httpd.log

web_log() {
    echo "$(date '+%m-%d %H:%M:%S') web: $*" >> "$LOG"
}

. "$MODDIR/lldv_cfg.sh"
[ "${WEB:-0}" = "1" ] || exit 0

_port=${WEB_PORT:-18765}
_user=${WEB_USER:-lldv}
_pass=${WEB_PASS:-}
case "$_port" in
    ''|*[!0-9]*) web_log "not started: WEB_PORT must be numeric"; exit 0 ;;
esac
if [ "$_port" -lt 1024 ] || [ "$_port" -gt 65535 ]; then
    web_log "not started: WEB_PORT must be 1024..65535"
    exit 0
fi
case "$_user" in
    ''|*[!A-Za-z0-9_.-]*) web_log "not started: WEB_USER may contain only letters, digits, '_', '.', '-'"; exit 0 ;;
esac
# Keep the password safe for the simple httpd.conf format and for shell sourcing.
case "$_pass" in
    ''|*[!A-Za-z0-9_.@#%+=,-]*)
        web_log "not started: WEB_PASS must be non-empty and use only letters, digits, or _.@#%+=,-"
        exit 0
        ;;
esac
if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF" 2>/dev/null)" 2>/dev/null; then
    exit 0
fi
if [ ! -x "$MODDIR/www/cgi-bin/lldv.cgi" ]; then
    web_log "not started: $MODDIR/www/cgi-bin/lldv.cgi is missing"
    exit 0
fi

# httpd.conf is on tmpfs, not in the module directory; the password is never written to the zip.
printf '/cgi-bin:%s:%s\n' "$_user" "$_pass" > "$CONF" || exit 0
chmod 600 "$CONF"
rm -f "$PIDF"
: > "$WEBLOG"
LLDV_MODDIR="$MODDIR" LLDV_OVERRIDE="$OVERRIDE" \
    nohup /data/adb/magisk/busybox httpd -f -p "$_port" -h "$MODDIR/www" -c "$CONF" >> "$WEBLOG" 2>&1 &
_pid=$!
echo "$_pid" > "$PIDF"
sleep 1
if kill -0 "$_pid" 2>/dev/null; then
    web_log "listening on port $_port (Basic Auth user $_user)"
else
    web_log "ERROR httpd failed to start on port $_port (see $WEBLOG)"
    rm -f "$PIDF"
fi
