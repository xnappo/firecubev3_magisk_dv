# TODO

## Make the watcher's poll pass cheaper (deferred)

Status: not started. Waiting for more real-life testing of v0.2.2 as is. Timing and behaviour would stay the same.

### Measured (v0.2.2, 192.168.1.188, box awake, 2026-11-15)

- Watcher and its child processes: 2.11 s of CPU in 29.5 s, about 7% of one core, **about 0.9% of the Cube's 8 cores**.
  About 140 ms of CPU per poll pass; 2.5 MB resident. Not visible in `top` next to the launcher (79%), the audio
  service (34%) and vizzini (31%). One sample only.
- About 97% of that CPU is in short-lived child processes (`cutime`/`cstime` in `/proc/<pid>/stat`), not in the
  checks themselves. Each idle pass starts about 15 processes.
- No visible effect on playback or the UI. It also runs in standby (the HDMI connection check starts processes too),
  so a little idle power and some wake-ups.
- The 2 s poll itself is needed: a standby wake re-reads the EDID with no plug event, so only polling catches it.

### Where the processes come from

- `reload_cfg` -> `lldv_effective` runs on every pass: `lldv_apply_primaries` / `lldv_apply_maxlum` inside `$(...)`,
  each with `echo | tr | tr`. The answer only changes when the settings change.
- `rd()` reads `hpd_state` and `hdr_priority_mode` with `$(cat ... | tr ...)`; `sink_has_dv` uses `$(head -1 ...)`;
  `vsvdb_now` uses `grep` + `echo | tr`.
- `lldv_file_trusted` runs `ls -ln` on the override file; the loop uses the external `sleep`.

### Plan (would be v0.2.3)

1. Cache the effective VSVDB: build a key from `$VSVDB|$PRIMARIES|$MAXLUM` after sourcing the settings, and only
   call `lldv_effective` when the key changes. Sourcing the settings files costs nothing.
2. Read sysfs with the shell's own `read -r _v < file` instead of `$(cat | tr)` / `$(head -1)`, stripping CR and
   spaces in shell. This must work in both mksh R56 and busybox ash (see AGENT.md device facts).
3. Keep the `ls -ln` permission check on the override file (security; one process per pass).
4. Expected result: an idle pass starts about 2 processes (`ls`, `sleep`) instead of about 15, roughly a 90% cut,
   standby included.

### Testing when it is done

- New unit checks: `rd`/`sink_has_dv`/`vsvdb_now` on fake sysfs files with a trailing CR and with no newline; the
  cache is rebuilt after `lldv set`.
- `dev_run_units.sh` (both shells), `dev_test_gamut.sh`, `dev_test_watch4.sh`, plus a real standby wake, a cable pull
  and a reboot, per AGENT.md hard rule 5.
- Measure the CPU again the same way and record the before/after in `captures/`.
- Release steps from AGENT.md (version bump, zip, `SHA256SUMS`, `.gitignore`, README Install and Revision history).

Not planned: raising the default `POLL`. Anyone who wants it lower already can set `POLL=5` in `/data/adb/lldv.conf`.
