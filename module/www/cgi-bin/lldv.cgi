#!/system/bin/sh
# The only state-changing endpoint is POST below. Values are checked against fixed lists before being passed to lldv.
MODDIR=${LLDV_MODDIR:-/data/adb/modules/firecube_lldv}
L="$MODDIR/lldv"
BB=/data/adb/magisk/busybox
. "$MODDIR/lldv_lum.sh"
. "$MODDIR/lldv_cfg.sh"

redirect() {
    printf 'Status: 303 See Other\r\nLocation: /cgi-bin/lldv.cgi\r\n\r\n'
    exit 0
}

header() {
    printf 'Content-Type: text/html; charset=utf-8\r\n\r\n'
}

selected() {
    [ "$1" = "$2" ] && printf ' selected'
}

page() {
    _msg=$1
    _show=$(sh "$L" show 2>&1)
    _esc=$($BB httpd -e "$_show")
    _msg_esc=$($BB httpd -e "$_msg")
    _cur_p=${PRIMARIES:-base}
    _cur_m=0
    if [ -n "$MAXLUM" ] && [ "$MAXLUM" != "0" ]; then
        _lm=$(lldv_lum_nearest "$MAXLUM")
        case "$_lm" in ERR:*) _cur_m=0 ;; *) _cur_m=${_lm#* } ;; esac
    fi
    header
    printf '%s\n' '<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">'
    printf '%s\n' '<title>Fire Cube LLDV</title><style>body{font:16px sans-serif;max-width:60em;margin:1em auto;padding:0 1em}pre{white-space:pre-wrap;background:#eee;padding:1em}select,button{font-size:1.1em;padding:.35em;margin:.25em}label{display:inline-block;min-width:9em}.warn{color:#a00}</style></head><body>'
    printf '%s\n' '<h1>Fire TV Cube 3 &mdash; Dolby Vision (LLDV)</h1>'
    [ -n "$_msg" ] && printf '<p class="warn">%s</p>\n' "$_msg_esc"
    printf '%s\n' '<form method="post" action="/cgi-bin/lldv.cgi"><input type="hidden" name="action" value="save">'
    printf '<label for="primaries">Primaries</label><select id="primaries" name="primaries">'
    for _p in base BT709 BT2020 DCI-P3 LS12000; do
        printf '<option value="%s"%s>%s</option>' "$_p" "$(selected "$_p" "$_cur_p")" "$_p"
    done
    printf '</select><br>\n'
    printf '<label for="maxlum">Max luminance</label><select id="maxlum" name="maxlum">'
    printf '<option value="0"%s>base block&apos;s own</option>' "$(selected 0 "$_cur_m")"
    for _m in $LLDV_LUM_NITS; do
        printf '<option value="%s"%s>%s cd/m2</option>' "$_m" "$(selected "$_m" "$_cur_m")" "$_m"
    done
    printf '</select><br><button type="submit">Apply settings</button></form>\n'
    printf '%s\n' '<form method="post" action="/cgi-bin/lldv.cgi"><input type="hidden" name="action" value="reset"><button type="submit">Reset overrides</button></form>'
    printf '%s\n' '<p>Changes use the existing <code>lldv</code> command and are applied by the watcher within seconds (the screen may blink once).</p>'
    printf '<h2>Current status</h2><pre>%s</pre>\n' "$_esc"
    printf '%s\n' '</body></html>'
}

case "${REQUEST_METHOD:-GET}" in
    GET)
        page ""
        ;;
    POST)
        _len=${CONTENT_LENGTH:-0}
        case "$_len" in ''|*[!0-9]*) _len=0 ;; esac
        [ "$_len" -le 4096 ] || { printf 'Status: 400 Bad Request\r\nContent-Type: text/plain\r\n\r\nRequest too large\n'; exit 0; }
        _body=$(dd bs=1 count="$_len" 2>/dev/null)
        _action= _p= _m=
        for _kv in $(printf '%s' "$_body" | tr '&' ' '); do
            case "$_kv" in
                action=*) _action=${_kv#action=} ;;
                primaries=*) _p=${_kv#primaries=} ;;
                maxlum=*) _m=${_kv#maxlum=} ;;
            esac
        done
        case "$_action" in
            reset)
                sh "$L" reset >/dev/null 2>&1 && redirect
                page "Reset failed"
                ;;
            save)
                case "$_p" in base|BT709|BT2020|DCI-P3|LS12000) ;; *) page "Invalid primaries value"; exit 0 ;; esac
                if [ "$_m" != "0" ]; then
                    case " $LLDV_LUM_NITS " in *" $_m "*) ;; *) page "Invalid maxLum value"; exit 0 ;; esac
                fi
                sh "$L" set primaries "$_p" >/dev/null 2>&1 || { page "Could not set primaries"; exit 0; }
                sh "$L" set maxlum "$_m" >/dev/null 2>&1 || { page "Could not set maxLum"; exit 0; }
                redirect
                ;;
            *) page "Unsupported action" ;;
        esac
        ;;
    *)
        printf 'Status: 405 Method Not Allowed\r\nAllow: GET, POST\r\n\r\n'
        ;;
esac
