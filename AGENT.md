# AGENT.md - notes for AI coding agents and maintainers

Read README.md first for what the project is. This file is what you need to change it without repeating the mistakes
already made. Everything here was observed on the real device unless marked *(inferred)*.

## Hard rules

1. **Every write to `/sys/class/amhdmitx/amhdmitx0/edid` must be exactly 16 bytes, no trailing newline**
   (`printf '%s' 'load /dev/lldv_p' > edid`). `edid_store()` returns 16 whatever the length, so any other length makes
   the shell resend the remainder as new commands. The Cube panicked once in this code path ("The panic" below).
   `lldv_watch.sh:edid_cmd()` enforces it; keep that guard. Do **not** use `echo "..." > edid` (adds a newline).
   Keep the paths short and on `/dev` (`/dev/ed`, `/dev/lldv_p`, `/dev/lldv_o`) so commands stay at 16 bytes.
2. Keep injections rare: one attempt per EDID+settings combination, a hold-off after each attempt. Never loop on the
   `edid` node.
3. **Never touch a DV block the module did not inject.** A change of settings may only rewrite a block whose reported
   VSVDB equals what the watcher injected (`INJECTED`).
4. `fake_plug 0` then `1` after a load is required: Android only re-reads display capabilities on a plug event. The
   kernel itself updates immediately on `load`.
5. Do not add anything that makes the module run an unbounded or fast loop at boot. The boot-loop guard
   (`lldv_guard.sh`) is the safety net; test any change to boot behaviour with real reboots, not only unit tests.

## Device facts (Fire TV Cube 3, "gazelle", Amlogic, kernel 5.4.125-ab25, Fire OS 7.7.1.7)

- Shells: `/system/bin/sh` is **mksh R56**; Magisk boot scripts run in busybox ash standalone mode. Test shell code
  under both (`tools/dev/dev_run_units.sh`). `${v:off:len}` and `$((0x..))` work in both.
- **`xxd -p | tr -d '\n'` leaves newlines in** on this toybox (256 bytes came out as 520 chars). Use
  `od -An -v -tx1 FILE | tr -d ' \012'` to get a hex string. `xxd -r -p` is fine.
- **This toybox's `xxd -r -p` silently drops UPPERCASE hex** (`00 FF FF` becomes one byte `00`, no error). `lldv edid`
  prints uppercase for analyzers, so lowercase it (`tr 'A-F' 'a-f'`) before reversing. The module's own hex strings
  are lowercase.
- **Android's awk is 20121220 and crashes ("illegal jump type 339")** on code that works elsewhere. No awk in the module.
- `dv_cap` is masked by `hdr_priority_mode`; **`dv_cap2` is the unmasked copy**, which is why the code reads it.
  The "no DV" text is `The Rx don't support DolbyVision`, which contains the word "DolbyVision": match on
  `support list` to detect DV, not on `DolbyVision`.
- `rawedid` is the live EDID as one hex string. The `edid` node's `save bin <file>` uses `O_CREAT` without `O_TRUNC`,
  so `rm` the target first.
- `hpd_state` does **not** change on a standby wake; the kernel re-reads the EDID in `hdmitx_late_resume()`. Hence the
  watcher polls state (every 2 s) rather than waiting for events.
- Magisk runs `service.sh` **twice per boot** (same `boot_id`, seconds apart); cause unknown. The guard counts per
  boot ID for this reason. The watcher's pid file (`/dev/lldv_watch.pid`) stops a second watcher.
- `sh` processes show up as `sh`, so `ps | grep lldv_watch` finds nothing. Check the pid file.
- Logging: `/data/local/tmp/lldv.log` (capped at ~100 KB). Kernel panics land in `/sys/fs/pstore/dmesg-ramoops-0`.
- With the test HDMI box in line, `sink_type` is `repeater`, and TV power-off / input switch never reach the Cube.

## The VSVDB format (v2, 12 bytes: header `eb`, ext tag `01`, OUI `46 d0 00`, 7 payload bytes)

Layout is that of `_edid_parsingvendspec()` in `hdmi_tx_edid.c` (ver 2 branch), checked against the device:

- byte 5: version (bits 7:5), DM version (4:2), backlight control (1), YCbCr422-12bit (0)
- byte 6: Target Min PQ (7:3), global dimming (2), backlt_min_luma (1:0)
- byte 7: **Target Max PQ code (7:3)**, Interface (1:0): 0 = low-latency only, 2 = standard + low-latency
- bytes 8..11: primaries. `Gx = b8>>1`, `Gy = 0x80|b9>>1`, `Rx = 0xA0|b10>>3`, `Ry = 0x40|b11>>3`,
  `Bx = 0x20|b10&7`, `By = 0x08|b11&7` (all /256). Bit 0 of bytes 8 and 9 hold the 10/12-bit 4:4:4 flags: keep them.
- Preset primaries are **rounded down** (floor) to the /256 code, not to the nearest: floor reproduces a known-good
  LS12000 calibration EDID bit for bit (`captures/ls12000_known_good.txt`), and the default base block's primaries are
  BT2020 floored. Do not switch back to nearest rounding. Python uses integer arithmetic so float error cannot cross
  a step (e.g. 0.6720*256 = 172.032).
- maxLum: PQ12 = 2055 + 65*code. The cd/m2 labels in `lldv_lum.sh` are a plain SMPTE ST 2084 calculation (code 9
  = 372); CoreELEC's decoder labels the same code "385". The code is unambiguous, the label is not.
- Every extension block is parsed; the **last** Dolby VSVDB wins. The patcher appends a block (max 8 blocks total).

## Code map

- `module/lldv_watch.sh`: watcher. `check_once` -> `inject_new` (save, patch, load, verify, plug cycle) or
  `inject_changed` (settings changed; patches the saved original `/dev/lldv_o`). Reads settings every pass.
- `module/lldv_edid.sh` `lldv_patch_edid in out vsvdb` -> `OK` | `PRESENT` | `ERR:...`. Appends the CTA block, fixes
  the count (byte 126; HF-EEODB branch exists but is untested) and checksums.
- `do_inject` (v0.2.3): after `load`, `dv_cap2` is re-read up to twice, 2 s apart. If the kernel still reports no DV,
  the patched EDID **stays loaded** (WARN in the log, `LAST_FAIL` + `HOLDOFF` stop retries); it no longer loads the
  original back, because a patched EDID that worked once is assumed good and the old restore left the Cube without DV
  after a slow sink (seen on a real box, 2026-11-15 18:05). Poll passes avoid forks: `rd`, `sink_has_dv` and
  `vsvdb_now` use shell builtins (CR cut off with `${v%"$_CR"}`), and `VSVDB_EFF` is recomputed only when
  `VSVDB|PRIMARIES|MAXLUM` change. The unit tests extract the real functions from `lldv_watch.sh` with `sed`, so keep
  each of them as a top-level `name() {` ... `}` block and `_CR=` on a line of its own.
- Do not delete `/dev/lldv_watch.pid` while a watcher runs (dev scripts did, and left three watchers writing to the
  `edid` node); stop the old one first. Magisk's double `service.sh` start is already handled by the pid check.
- `module/lldv_lum.sh`, `lldv_gamut.sh`: pure functions on a VSVDB hex string -> new hex string or `ERR:...`.
  Python reference implementations live in `tools/dv_vsvdb.py`; if you change one, change both and diff the output.
- `module/lldv_cfg.sh`: settings layers. `lldv_effective` computes `VSVDB_EFF`. Sourced files run as shell, hence the
  ownership/permission check on `/data/adb/lldv.conf`.
- `module/lldv_guard.sh`: boot-loop guard, state in `/data/adb/lldv_boot_state` (`<boot_id> <count> <tripped>`).
- `module/lldv`: the user command (`show list set cycle reset edid log`). `lldv edid` is read-only: stdout is only hex,
  the summary goes to stderr, and it never writes to the `edid` node. `module/action.sh`: Magisk Action button
  (read-only: module version + `lldv show` + example `su` commands; it must not change any setting).

## Workflow

- Dev loop over adb (the device address is your own): edit under `module/`, `adb push` it to
  `/data/local/tmp/lldv_mod/`, run a script from `tools/dev/` as root. **Do not** test by editing the installed copy.
  The `tools/dev/` scripts expect to be pushed to `/data/local/tmp/` and run from there, and several expect
  `/data/local/tmp/lldv_mod/` to hold the module and `/dev/ed` to hold the display's own 256-byte EDID.
- Package: `python3 tools/build_zip.py module dist/<name>.zip` (LF endings, exec bits, fixed timestamps: the output is
  byte-for-byte reproducible). Install with `magisk --install-module`; Magisk applies it at the next reboot.
- **Releasing:** bump `version`/`versionCode` in `module/module.prop`, build `dist/firecube_lldv-<version>.zip`,
  write `dist/SHA256SUMS` (`<sha256>  <zipname>`, LF, no BOM), add the new zip to the `dist/` allow-list in
  `.gitignore`, update the version in README's Install section, commit the zip with the code, then push. Only the
  current release zip is tracked; do not commit older dev builds.
- Unit tests: `tools/dev/dev_run_units.sh` (83 checks, both shells; push `captures/edid_orig.bin` and
  `edid_nodv_plus_dv3.bin` to `/data/local/tmp` first, the `lldv edid` tests read them). Live tests need the in-line
  DV/non-DV box. `tools/dev/dev_check_edid_cmd.sh` compares `lldv edid` with the EDID files the watcher loaded.
- **Windows host gotchas:** shell scripts must be LF (`.gitattributes` enforces it). adb output often was not
  captured by the terminal, so tests write results to a file that is then read. Run long device commands in the
  background (`nohup ... &`) and poll a result file. PowerShell expands `$(...)` and splits on `|` inside quoted adb
  commands: put non-trivial device commands in a script file and push it.
- `captures/` holds the evidence behind claims in README. Keep claims and evidence in step; do not claim a test passed
  that no capture shows. Raw captures are git-ignored; add a file to the `!` list in `.gitignore` to keep it.
- v0.2.2 device evidence: `captures/test80_units_v022.txt` (unit checks, both shells), `test81_gamut_v022.txt`
  (primaries), `test82_watch4_v022.txt` (end-to-end: kernel-reported VSVDB per preset), `test83_live_restore_v022.txt`
  (the test wrapper put the user's `/data/adb/lldv.conf` back and restarted the installed watcher).
  `dev_test_watch4.sh` overwrites and then deletes `/data/adb/lldv.conf` and stops the watcher: on a box in real
  use, back the file up first and restart the watcher afterwards.

## Things deliberately NOT done / open questions

- The guard's *trip* path (4 bad boots) was never exercised for real; only unit-tested.
- A kernel-module approach (kretprobe on `hdmitx21_edid_parse`) was researched, not built. See README.
- Cause of the double `service.sh` run, and of the ~11 s delay between watcher start and first action at boot, unknown.
- The panic's root cause is unproven ("The panic" below).
- No license chosen. Do not add one on the owner's behalf.

## The panic

During development the Cube kernel-panicked once (`captures/pstore_dmesg.txt`): an Oops in `__kmalloc_track_caller`
called from `edid_store` (the `edid` sysfs node), in the shell that was writing to it. `edid_store()` in Amazon's
`hdmi_tx_main.c` always returns 16, whatever the write length, so a command that is not exactly 16 bytes makes the
shell resend the remainder, which the kernel parses as more commands (`d`, `e`, `h`, ...). Many such writes had gone
through the node before the crash. That is the best explanation, not a proven cause: the corrupted memory predates
the crashing call. Hence hard rule 1. No panic has occurred since the 16-byte rule went in.

## Style

Shell: POSIX-ish, tested under mksh and busybox ash; quote variables; `_names` for function temporaries (sourced
files share one namespace, so a function that changes `$1`..`$n` with `set --` must live in its own function).
Comments explain *why* (device quirks, safety). No functionality that depends on awk, `xxd -p` line handling or
Python on the device (there is no Python on the Cube).
