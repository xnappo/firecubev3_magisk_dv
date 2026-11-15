# Fire TV Cube 3: Dolby Vision (LLDV) on non-DV displays

A Magisk module for a **rooted Fire TV Cube 3rd gen ("gazelle")**. When the connected display does not report Dolby
Vision, the module adds a Dolby Vision VSVDB to the EDID the Cube works from, so the Cube offers **low-latency Dolby
Vision (LLDV)** to a display that cannot do DV itself (a projector, for example). It re-applies the change after
hotplug, standby wake and boot, and leaves real Dolby Vision displays alone.

> **Status: working prototype, tested on one device.** Fire OS 7.7.1.7 (PS7717/5741), kernel 5.4.125-ab25,
> Magisk 30.7, with an HDMI box that switches between a DV and a non-DV EDID standing in for a non-DV display.
> **Not yet tested:** a real projector, picture quality, and what `MAXLUM`/`PRIMARIES` do to the image (see
> [What is and isn't verified](#what-is-and-isnt-verified)).
>
> **About v0.2.2 specifically:** the full set of device tests ran on v0.2.0 as installed. v0.2.1 added the read-only
> `lldv edid` command (tested from a copy on the Cube: 72 unit checks, and a live comparison against the EDID files
> the watcher loaded). v0.2.2 changes the `PRIMARIES` presets to round down to the 1/256 step instead of to the
> nearest one, which matches a known-good LS12000 calibration EDID bit for bit; that was checked on a PC (shell code
> under bash and busybox ash, against the Python reference), but **the v0.2.2 zip has not been tested on a device yet**.

> **Risk.** The module writes to a kernel sysfs node that panicked the Cube once during development
> ([The panic](#the-panic)). The shipped code avoids the cause I found, but I could not prove that was the cause.
> A boot-loop guard disables the module after 4 unstable boots in a row. Unofficial, no warranty, you need root.

## How it works

1. The Cube's kernel parses the display's EDID and exposes the result in `/sys/class/amhdmitx/amhdmitx0/`
   (`dv_cap2`, `hdr_cap`, `rawedid`, ...). The `edid` node can `save` the live EDID to a file and `load` one back.
2. When `dv_cap2` says the display has no Dolby Vision, the watcher saves the live EDID, **appends one extra CTA
   extension block that contains only the Dolby VSVDB**, fixes the block count and checksums, and loads it back.
   Appending a block (not editing the existing one) matters because many displays' CTA blocks are full and have no
   room for the 12-byte VSVDB. The kernel parser walks every CTA block, so a separate block always works.
3. Android only re-reads the display capabilities on a plug event, so after loading the watcher cycles
   `fake_plug` 0 then 1 (a short screen blink).
4. A loaded EDID is thrown away whenever the kernel re-reads the display (hotplug, and also a standby wake **with no
   plug event at all**). So the watcher polls the *state* every 2 s instead of waiting for events, and re-injects.

Details that were found the hard way are in [AGENT.md](AGENT.md).

## Requirements

- Fire TV Cube 3rd gen (`ro.product.device` = `gazelle`), rooted with Magisk 20.4 or newer (tested with 30.7).
- The installer refuses other devices and firmware without `/sys/class/amhdmitx/amhdmitx0/dv_cap2`.

## Install

The ready-built module is [`dist/firecube_lldv-v0.2.2.zip`](dist/firecube_lldv-v0.2.2.zip) (about 18 KB), version
v0.2.2. Its SHA-256 is in [`dist/SHA256SUMS`](dist/SHA256SUMS); check the download with
`sha256sum -c dist/SHA256SUMS` (Linux/macOS/WSL) or `Get-FileHash dist\firecube_lldv-v0.2.2.zip` (PowerShell). The
build is reproducible: `python3 tools/build_zip.py module dist/firecube_lldv-v0.2.2.zip` regenerates the same bytes.

Install it from the Magisk app (Modules, Install from storage) or, over adb (this is the route used in testing):

```
adb push dist/firecube_lldv-v0.2.2.zip /data/local/tmp/
adb shell su -c "magisk --install-module /data/local/tmp/firecube_lldv-v0.2.2.zip"
```

Reboot. In testing the watcher started about 8 s after `service.sh` and had injected about 25 s after it. Check with:

```
adb shell su -c /data/adb/modules/firecube_lldv/lldv show
```

## Settings

Defaults: base block `eb0146d0004903485798a953` (VSVDB v2, low-latency only, YCbCr 4:2:2 12-bit), `MAXLUM=385`,
primaries as in the base block. Layers, later wins: built-in defaults, the module's `lldv.conf`,
`/data/adb/lldv.conf` (your overrides, survive module updates).

The `lldv` command (run as root) changes them. The running watcher picks the change up within seconds and re-injects
(one screen blink); no reboot.

| Command | Effect |
|---|---|
| `lldv show` | settings, what the display reports, watcher state, last log lines |
| `lldv list` | the selectable maxLum values and primaries presets |
| `lldv set maxlum <cd/m2>` | peak luminance; snaps to the nearest of 32 steps; `0` keeps the base block's value |
| `lldv set primaries <name>` | `BT709`, `BT2020`, `DCI-P3`, `LS12000`, or `base` |
| `lldv cycle` | next primaries preset (the Magisk app's **Action** button runs this) |
| `lldv reset [maxlum\|primaries]` | remove the override(s) |
| `lldv edid [orig]` | the EDID as hex, 16 bytes per line, to paste into an EDID analyzer (see below) |
| `lldv log [n]` | tail of `/data/local/tmp/lldv.log` |

**`lldv edid`** prints the live EDID the kernel holds now, which includes the injected block (3 blocks, 384 bytes,
when the module has injected). `lldv edid orig` prints the display's own EDID as the module saved it just before
injecting; it only exists after an injection since boot. Only hex goes to stdout, so `lldv edid > edid.txt` captures
just the hex; a one-line summary (block count, header, per-block checksums, with `BAD HEADER` / `BAD CHECKSUM`
flagged) goes to stderr. It only reads; it never writes to the kernel's `edid` node.

```
00 FF FF FF FF FF FF 00 34 A3 01 00 01 00 00 00
04 19 01 03 80 73 41 78 0A CF 74 A3 57 4C B0 23
...
```

The output is uppercase, space-separated hex. Analyzers that take a hex dump accept this directly. To turn it back
into a binary file on the Cube, lowercase it first: this toybox's `xxd -r -p` silently drops uppercase hex.

Example: `su -c /data/adb/modules/firecube_lldv/lldv set primaries DCI-P3`

**maxLum** is a 5-bit field, so only these 32 values exist (cd/m2): 94 110 129 150 175 204 237 276 320 372 431 499
578 670 775 897 1037 1200 1387 1605 1856 2147 2485 2876 3330 3857 4470 5183 6014 6982 8113 9434. `385` becomes `372`
(code 9, the value in the base block). Other tools label code 9 as "385"; the code in the EDID is what counts.

**Primaries** are stored in 1/256 steps, rounded down (this matches a known-good LS12000 calibration EDID bit for
bit, `captures/ls12000_known_good.txt`; the default base block's primaries are BT2020 rounded down too):

| Preset | Requested (Rx Ry / Gx Gy / Bx By) | Stored |
|---|---|---|
| BT709 | .6400 .3300 / .3000 .6000 / .1500 .0600 | .6367 .3281 / .2969 .5977 / .1484 .0586 |
| BT2020 | .7080 .2920 / .1700 .7970 / .1310 .0460 | .7070 .2891 / .1680 .7969 / .1289 .0430 |
| DCI-P3 | .6800 .3200 / .2650 .6900 / .1500 .0600 | .6797 .3164 / .2617 .6875 / .1484 .0586 |
| LS12000 Native | .6670 .3310 / .3140 .6720 / .1480 .0420 | .6641 .3281 / .3125 .6719 / .1445 .0391 |

With the default base block, `BT2020` therefore gives the same VSVDB as `base` (nothing is re-injected).

Each coordinate has a limited reachable range in a v2 block (blue only 8 steps per axis); see
`module/lldv_gamut.sh`. The v2 block has no white-point field.

You can also edit `/data/adb/lldv.conf` by hand (`VSVDB=`, `MAXLUM=`, `PRIMARIES=`, `POLL=`, `SETTLE=`,
`HOLDOFF=`). It is sourced as shell, so it is ignored unless owned by root and not group/world-writable.

## What is and isn't verified

Tested on the Cube with an HDMI box in line that presents either a DV or a non-DV EDID (it reports as `repeater`):

| Verified | How |
|---|---|
| Injection at boot | module installed, rebooted, watcher injected on its own |
| Injection after a cable pull and replug | log and kernel events |
| Box switched DV position, then non-DV | no injection while the box supplied DV; one injection after the flip back |
| **Real standby wake** | kernel re-read the EDID at late resume with no plug event; watcher re-injected about 5 s later |
| Live settings change (`lldv set`, Action button) | each change re-injected the new block, no reboot |
| All four primaries presets and maxLum | the VSVDB the kernel reports matches the expected bytes |
| Boot-loop guard counting and its 5-minute clear | real boots; the guard *tripping* was not exercised |
| Shell code on the device | 72 unit checks pass under both the adb shell and Magisk's busybox ash |
| `lldv edid` | output round-trips byte-for-byte to the EDID file the watcher loaded (live) and to the saved original |

| NOT verified | Notes |
|---|---|
| **Any picture or real Dolby Vision playback** | nobody has looked at LLDV through this yet; a projector test is planned |
| Whether `MAXLUM`/`PRIMARIES` change the image | the EDID carries them and the Cube advertises them; whether the closed-source `dovi.ko` uses them is unknown |
| A real non-DV display connected directly | only an in-line box that spoofs the EDID was used |
| TV power-off and input switch with the box in line | the box hid them from the Cube; with the TV direct, both appear as a plug-out/plug-in, which is the same event as the cable pull |
| Other firmware versions | tested on 7.7.1.7 only; the source read was 7.7.1.4 |
| An AVR or other device in the HDMI chain | untested |
| The EDID `HF-EEODB` branch of the patcher | no sample EDID uses it |
| Why Magisk runs `service.sh` twice per boot | seen in the log; the guard copes with it, the cause is unknown |

## The panic

During development the Cube kernel-panicked once (`captures/pstore_dmesg.txt`): an Oops in
`__kmalloc_track_caller` called from `edid_store` (the `edid` sysfs node), in the shell that was writing to it.

`edid_store()` in Amazon's `hdmi_tx_main.c` **always returns 16**, whatever the write length. A command that is not
exactly 16 bytes therefore makes the shell resend the remainder as new commands, which the kernel parses as more
commands (`d`, `e`, `h`, ...). Many such writes had gone through the node before the crash. That is my best
explanation; **I could not prove it was the cause**, and the corrupted memory predates the crashing call.

The module therefore writes to the `edid` node only with commands of **exactly 16 bytes and no newline**
(`save bin /dev/ed`, `load /dev/lldv_p`, `load /dev/lldv_o`) at fixed paths on `/dev`, refuses any other length, and
makes a handful of writes per injection. No panic has occurred since.

## Troubleshooting and removal

- Log: `/data/local/tmp/lldv.log` (also `lldv log`). State: `lldv show`.
- Boot-loop guard: after 4 unstable boots in a row (uptime under 5 minutes) it creates
  `/data/adb/modules/firecube_lldv/disable` and logs why. Remove that file and reboot to re-enable.
- Stop temporarily: `touch /data/adb/modules/firecube_lldv/disable` and reboot.
- Uninstall: Magisk app, or `touch /data/adb/modules/firecube_lldv/remove` and reboot. The display's own EDID is back
  after the next hotplug or reboot. `/data/adb/lldv.conf` is left in place on purpose.

## Repository layout

| Path | What |
|---|---|
| `module/` | the Magisk module (what goes in the zip) |
| `module/lldv_watch.sh` | the watcher; `lldv_edid.sh` EDID patcher; `lldv_lum.sh` maxLum; `lldv_gamut.sh` primaries; `lldv_cfg.sh` settings; `lldv_guard.sh` boot-loop guard |
| `module/lldv`, `action.sh` | the settings command and the Magisk Action button |
| `tools/` | `build_zip.py`, `dv_vsvdb.py` (VSVDB decoder, maxLum table, gamut reference encoder), `edid_tool.py` |
| `tools/dev/` | scripts pushed to `/data/local/tmp` and run as root on the Cube during development (tests, status, probes) |
| `tools/wsl/` | scripts that run in WSL/Linux (extract Amazon's source, regenerate reports) |
| `dist/` | the built module zip for the current version, plus `SHA256SUMS` |
| `captures/` | curated evidence from the Cube (the original EDID, probe results, test results, the panic excerpt) |
| `AGENT.md` | notes for AI coding agents and future maintainers |

`dist/` holds the current release zip and its `SHA256SUMS`. `src/` (Amazon's 2 GB kernel source tarball and the files
read from it) is not tracked, and neither are older dev builds of the zip.

## Reference source

Amazon publishes the kernel source for the Cube 3: `FireTVCubeGen3-7.7.1.4-20260624.tar.bz2` from
`https://fireos-tv-src.s3.amazonaws.com/C4PWIMXUTMxbwcQ2xRkOmIeodX/` (about 2 GB). The kernel is inside the nested
`platform.tar`, under `kernel/amlogic/pop1g/5.4/common/`. The relevant files are
`drivers/amlogic/media/vout/hdmitx21/hdmi_tx_edid.c` and `hdmi_tx_main.c`, and
`include/linux/amlogic/media/vout/{vinfo.h,hdmi_tx21/*.h}`. `tools/wsl/` automates the extraction. The tarball is
7.7.1.4 and the tested device runs 7.7.1.7. I only relied on the VSVDB bit layout, and checked it against the device:
the VSVDB the kernel reports after every injection matched the bytes the module built.

A kernel-module approach (hooking `hdmitx21_edid_parse` with a kretprobe to patch the parsed DV info in memory) was
investigated and not built. The kernel config has KPROBES and no `CONFIG_MODULE_SIG`, but it is built with CFI,
ShadowCallStack, MODVERSIONS and ThinLTO, so a module would need the exact toolchain and carries a real risk of a
crash. The EDID route needs none of that.

## License

No license has been chosen yet.
