#!/system/bin/sh
# Dev test (run as root on the Cube): exercise the web CGI under both supported shells.
# Uses an isolated override file; the real /data/adb/lldv.conf must remain unchanged.
# Output -> /data/local/tmp/web_cgi_tests_out.txt
T=/data/local/tmp
M=$T/lldv_mod
O=$T/lldv_web_cgi_override
OUT=$T/web_cgi_tests_out.txt
: > "$OUT"
REAL_BEFORE=$(md5sum /data/adb/lldv.conf 2>/dev/null)
cat > "$O" <<'EOF'
WEB=1
WEB_PORT=18765
PRIMARIES=LS12000
MAXLUM=372
EOF
chmod 600 "$O"
run_cgi() {
    _method=$1
    _body=$2
    _shell=$3
    _len=${#_body}
    if [ "$_shell" = busybox ]; then
        printf '%s' "$_body" | REQUEST_METHOD="$_method" CONTENT_LENGTH="$_len" LLDV_MODDIR=$M LLDV_OVERRIDE=$O ASH_STANDALONE=1 /data/adb/magisk/busybox sh "$M/www/cgi-bin/lldv.cgi"
    else
        printf '%s' "$_body" | REQUEST_METHOD="$_method" CONTENT_LENGTH="$_len" LLDV_MODDIR=$M LLDV_OVERRIDE=$O sh "$M/www/cgi-bin/lldv.cgi"
    fi
}
for S in adb busybox; do
    run_cgi GET '' "$S" > "$T/get_$S.html" 2>&1
    if grep -q 'Current status' "$T/get_$S.html"; then echo "PASS $S GET" >> "$OUT"; else echo "FAIL $S GET" >> "$OUT"; fi
    run_cgi POST 'action=save&primaries=BT709&maxlum=372' "$S" > "$T/post_$S.txt" 2>&1
    if grep -q '^Status: 303 See Other' "$T/post_$S.txt" && grep -q '^PRIMARIES=BT709$' "$O"; then echo "PASS $S valid POST" >> "$OUT"; else echo "FAIL $S valid POST" >> "$OUT"; fi
    run_cgi POST 'action=save&primaries=bogus&maxlum=372' "$S" > "$T/bad_$S.txt" 2>&1
    if grep -q 'Invalid' "$T/bad_$S.txt" && grep -q '^PRIMARIES=BT709$' "$O"; then echo "PASS $S invalid POST rejected" >> "$OUT"; else echo "FAIL $S invalid POST" >> "$OUT"; fi
    run_cgi POST 'action=save&primaries=LS12000&maxlum=372' "$S" > "$T/restore_$S.txt" 2>&1
    grep -q '^PRIMARIES=LS12000$' "$O" && echo "PASS $S restore" >> "$OUT" || echo "FAIL $S restore" >> "$OUT"
done
REAL_AFTER=$(md5sum /data/adb/lldv.conf 2>/dev/null)
[ "$REAL_BEFORE" = "$REAL_AFTER" ] && echo "PASS real /data/adb/lldv.conf unchanged" >> "$OUT" || echo "FAIL real config changed" >> "$OUT"
echo "DONE" >> "$OUT"
