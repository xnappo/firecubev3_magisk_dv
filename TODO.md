# TODO

## Make the watcher's poll pass cheaper — IMPLEMENTED (v0.2.3)

Status: done. Committed as aa0b910. Changes to module/lldv_watch.sh:

1. **do_inject() retry**: after loading the patched EDID, re-check dv_cap2 up to
   two more times (2 s apart) before restoring the original EDID. Only dv_cap2
   is re-read (read-only sysfs); the edid node is written once, as before.
   Avoids a spurious restore when a sink takes longer than 2 s to re-parse the
   EDID after load /dev/lldv_p.

2. **Reduced poll CPU cost**:
   - VSVDB_EFF is cached keyed on $VSVDB|$PRIMARIES|$MAXLUM, so lldv_effective
     runs once per settings change instead of every poll.
   - rd(), sink_has_dv() and vsvdb_now() use read -r instead of cat | tr /
     head -1 / grep | tr, so an idle poll starts about 2 subprocesses instead
     of about 15.

Measured on 192.168.1.76 (Fire OS 7.7.1.7): watcher+children CPU dropped from
about 0.9% to about 0.55% of the Cube's 8 cores. 72 unit checks pass under
both shells, 17 primaries checks pass. Line endings are LF throughout.

Nothing else is planned on this line.
