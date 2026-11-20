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
    _module_version=$(grep -m1 '^version=' "$MODDIR/module.prop" 2>/dev/null | tr -d '\r')
    _module_version=${_module_version#version=}
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
    cat <<'HTML'
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Fire Cube LLDV</title>
<link rel="icon" type="image/png" href="/favicon.png">
<link rel="apple-touch-icon" href="/favicon.png">
<style>
:root{--bg:#0f172a;--panel:#111827;--panel-light:#1f2937;--text:#e5e7eb;--muted:#9ca3af;--primary:#3b82f6;--primary-dark:#2563eb;--accent:#22c55e;--warn:#f59e0b}
*{box-sizing:border-box}
body{margin:0;min-height:100vh;font-family:"Segoe UI",Tahoma,Geneva,Verdana,sans-serif;background:radial-gradient(circle at top,#1e293b 0%,#0f172a 45%,#020617 100%);color:var(--text)}
.container{max-width:960px;margin:0 auto;padding:32px 20px 48px}
.header{display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;margin-bottom:24px}
.header h1{margin:0;font-size:28px;letter-spacing:.5px}
.header p{margin:6px 0 0;color:var(--muted);font-size:14px}
.badge{padding:4px 10px;border-radius:999px;background:rgba(34,197,94,.15);color:#86efac;font-size:12px;font-weight:600}
.card{background:linear-gradient(180deg,var(--panel) 0%,var(--panel-light) 100%);border:1px solid rgba(255,255,255,.06);border-radius:16px;padding:20px;box-shadow:0 20px 40px rgba(0,0,0,.35);margin-bottom:24px}
.card h2{margin-top:0;font-size:20px}
label{display:block;font-size:14px;margin-bottom:6px;color:var(--muted)}
select{width:100%;padding:12px 14px;font-size:16px;color:var(--text);background:#0b1220;border:1px solid rgba(255,255,255,.1);border-radius:10px;margin-bottom:14px}
.actions{display:flex;gap:12px;align-items:center;flex-wrap:wrap}
.btn{border:none;border-radius:10px;padding:10px 18px;font-size:15px;font-weight:600;cursor:pointer;transition:transform .1s ease,background .2s ease}
.btn-primary{background:var(--primary);color:#fff}
.btn-primary:hover{background:var(--primary-dark);transform:translateY(-1px)}
.btn-ghost{background:transparent;color:var(--muted);border:1px solid rgba(255,255,255,.15)}
.btn-ghost:hover{color:var(--text);border-color:rgba(255,255,255,.3)}
.warn{padding:12px 14px;border-radius:10px;background:rgba(245,158,11,.15);border:1px solid rgba(245,158,11,.4);color:#fbbf24;margin-bottom:16px}
.helper{font-size:13px;color:var(--muted);margin:14px 0 0}
.helper a{color:var(--primary);text-decoration:none}
code{background:#0b1120;padding:2px 6px;border-radius:6px;color:#e2e8f0;font-family:Consolas,monospace}
pre.output,textarea.hex-input{background:#0b1120;border-radius:12px;border:1px solid rgba(255,255,255,.08);padding:14px;white-space:pre-wrap;font-family:Consolas,monospace;color:#e2e8f0;margin:0;overflow-x:auto;line-height:1.45;width:100%;font-size:13px}
textarea.hex-input{min-height:150px;resize:vertical;margin-top:12px}
.edid-grid{display:grid;gap:16px;grid-template-columns:1fr;margin-top:12px}
.subhead{font-size:13px;font-weight:600;color:var(--muted);margin:12px 0 6px;display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:8px}
hr{border:0;border-top:1px solid rgba(255,255,255,.08);margin:18px 0}
footer{margin-top:28px;color:var(--muted);font-size:12px;text-align:center}
</style></head><body><div class="container">
HTML
    printf '<div class="header"><div><h1>Fire TV Cube 3 &mdash; Dolby Vision (LLDV) %s</h1><p>Low-latency Dolby Vision EDID settings &amp; live status</p></div><div class="badge">%s</div></div>\n' "$_module_version" "$_module_version"
    [ -n "$_msg" ] && printf '<div class="warn">%s</div>\n' "$_msg_esc"
    printf '%s\n' '<div class="card"><h2>Settings</h2><form method="post" action="/cgi-bin/lldv.cgi"><input type="hidden" name="action" value="save">'
    printf '<label for="primaries">Primaries</label><select id="primaries" name="primaries">'
    for _p in base BT709 BT2020 DCI-P3 LS12000; do
        _plbl=$_p
        [ "$_p" = "base" ] && _plbl="base (BT2020)"
        printf '<option value="%s"%s>%s</option>' "$_p" "$(selected "$_p" "$_cur_p")" "$_plbl"
    done
    printf '</select>\n'
    printf '<label for="maxlum">Max luminance</label><select id="maxlum" name="maxlum">'
    printf '<option value="0"%s>base block&apos;s own</option>' "$(selected 0 "$_cur_m")"
    for _m in $LLDV_LUM_NITS; do
        printf '<option value="%s"%s>%s cd/m2</option>' "$_m" "$(selected "$_m" "$_cur_m")" "$_m"
    done
    printf '</select><div class="actions"><button class="btn btn-primary" type="submit">Apply settings</button></div></form>\n'
    printf '%s\n' '<hr><form method="post" action="/cgi-bin/lldv.cgi"><input type="hidden" name="action" value="reset"><div class="actions"><button class="btn btn-ghost" type="submit">Reset overrides</button></div></form>'
    printf '%s\n' '<p class="helper">Changes use the existing <code>lldv</code> command and are applied by the watcher within seconds (the screen may blink once).</p></div>'
    printf '<div class="card"><h2>Current status</h2><pre class="output">%s</pre></div>\n' "$_esc"
    cat <<'HTML'
<div class="card">
<h2>EDID Analyzer (edid-decode)</h2>
<div class="actions">
<button class="btn btn-primary" type="button" onclick="loadEdid('live')">Decode Live EDID</button>
<button class="btn btn-ghost" type="button" onclick="loadEdid('orig')">Decode Original EDID</button>
<button class="btn btn-ghost" type="button" onclick="decodeHexBox()">Decode Hex Box</button>
<button class="btn btn-ghost" type="button" onclick="copyEdidHex()">Copy Hex</button>
</div>
<div class="subhead"><span id="edid-summary">Click &ldquo;Decode Live EDID&rdquo; or &ldquo;Decode Original EDID&rdquo;, or paste EDID hex below.</span><span id="edid-copy-msg"></span></div>
<textarea id="edid-input" class="hex-input" spellcheck="false" placeholder="EDID hex (16 bytes per line) will appear here..."></textarea>
<div class="subhead"><span>Decoded Output (v4l-utils edid-decode WebAssembly)</span></div>
<pre id="edid-output" class="output">Loading local edid-decode WebAssembly module...</pre>
<pre id="edid-error" class="output" style="display:none;margin-top:12px;border-color:rgba(245,158,11,.4);color:#fbbf24"></pre>
<p class="helper">Runs <code>edid-decode</code> locally in your browser via WebAssembly (from <a href="https://hverkuil.home.xs4all.nl/edid-decode/edid-decode.html" target="_blank" rel="noopener">edid-decode.html</a> / <a href="https://git.linuxtv.org/v4l-utils.git/" target="_blank" rel="noopener">v4l-utils</a>). Read-only: never writes to the kernel&apos;s <code>edid</code> node.</p>
</div>
<script>
var wasmReady = false;
var pendingDecode = false;
var Module = {
  noInitialRun: true,
  locateFile: function(path) { return '/' + path; },
  postRun: [function() {
    wasmReady = true;
    var out = document.getElementById('edid-output');
    if (pendingDecode) {
      pendingDecode = false;
      decodeHexBox();
    } else if (out && out.textContent.indexOf('Loading local') === 0) {
      out.textContent = 'Ready. Click "Decode Live EDID" above.';
    }
  }],
  print: function(text) {
    if (arguments.length > 1) text = Array.prototype.slice.call(arguments).join(' ');
    var el = document.getElementById('edid-output');
    if (el) el.textContent += text + '\n';
  },
  printErr: function(text) {
    if (arguments.length > 1) text = Array.prototype.slice.call(arguments).join(' ');
    var el = document.getElementById('edid-error');
    if (el) {
      el.style.display = 'block';
      el.textContent += text + '\n';
    }
  }
};
function decodeHexBox() {
  var hex = (document.getElementById('edid-input').value || '').trim();
  var out = document.getElementById('edid-output');
  var err = document.getElementById('edid-error');
  if (!hex) {
    out.textContent = 'No EDID hex to decode.';
    err.style.display = 'none';
    return;
  }
  if (!wasmReady || typeof FS === 'undefined' || !Module.ccall) {
    pendingDecode = true;
    out.textContent = 'Waiting for edid-decode WebAssembly module...';
    return;
  }
  out.textContent = '';
  err.textContent = '';
  err.style.display = 'none';
  try {
    FS.writeFile('input-file', hex + '\n');
    Module.ccall('parse_edid', 'number', ['string', 'number'], ['input-file', 0]);
    if (!out.textContent.trim()) {
      out.textContent = 'edid-decode produced no output (check the hex input).';
    }
  } catch (e) {
    err.style.display = 'block';
    err.textContent = 'Decode error: ' + e;
  }
}
function loadEdid(which) {
  var sum = document.getElementById('edid-summary');
  var inp = document.getElementById('edid-input');
  var out = document.getElementById('edid-output');
  var err = document.getElementById('edid-error');
  sum.textContent = 'Fetching ' + (which === 'orig' ? 'original' : 'live') + ' EDID...';
  err.style.display = 'none';
  fetch('/cgi-bin/lldv.cgi?edid=' + encodeURIComponent(which), { cache: 'no-store' })
    .then(function(r) { return r.text(); })
    .then(function(txt) {
      var lines = txt.replace(/\r/g, '').split('\n');
      var summary = '';
      var hexLines = [];
      for (var i = 0; i < lines.length; i++) {
        var ln = lines[i].trim();
        if (!ln) continue;
        if (ln.indexOf('#') === 0) {
          summary = ln.replace(/^#\s*/, '');
        } else if (ln.indexOf('lldv:') === 0) {
          sum.textContent = ln;
          inp.value = '';
          out.textContent = ln;
          return;
        } else {
          hexLines.push(ln);
        }
      }
      sum.textContent = summary || ((which === 'orig' ? 'Original' : 'Live') + ' EDID');
      inp.value = hexLines.join('\n');
      decodeHexBox();
    })
    .catch(function(e) {
      sum.textContent = 'Failed to fetch EDID: ' + e;
    });
}
function copyEdidHex() {
  var inp = document.getElementById('edid-input');
  var msg = document.getElementById('edid-copy-msg');
  if (!inp || !inp.value.trim()) {
    msg.textContent = 'Nothing to copy';
    return;
  }
  inp.select();
  inp.setSelectionRange(0, 99999);
  try {
    document.execCommand('copy');
    msg.textContent = 'Copied to clipboard';
  } catch (e) {
    msg.textContent = 'Copy failed';
  }
  setTimeout(function() { msg.textContent = ''; }, 2500);
}
window.addEventListener('DOMContentLoaded', function() { loadEdid('live'); });
</script>
<script async src="/edid-decode.js"></script>
HTML
    printf '<footer>Fire TV Cube 3 LLDV Web UI &middot; %s</footer></div></body></html>\n' "$_module_version"
}

case "${REQUEST_METHOD:-GET}" in
    GET)
        case "${QUERY_STRING:-}" in
            edid=live)
                printf 'Content-Type: text/plain; charset=utf-8\r\nCache-Control: no-store\r\n\r\n'
                sh "$L" edid 2>&1
                ;;
            edid=orig)
                printf 'Content-Type: text/plain; charset=utf-8\r\nCache-Control: no-store\r\n\r\n'
                sh "$L" edid orig 2>&1
                ;;
            *)
                page ""
                ;;
        esac
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
