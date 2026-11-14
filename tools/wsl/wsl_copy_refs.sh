#!/bin/bash
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# Copies reference kernel sources (hdmitx21 EDID parser + headers) from the extracted Amazon tree into src/ref.
B="$HOME/fcsrc/plat/kernel/amlogic/pop1g/5.4/common"
D=$ROOT/src/ref
mkdir -p "$D"
cp "$B/drivers/amlogic/media/vout/hdmitx21/hdmi_tx_edid.c" "$D/hdmitx21_hdmi_tx_edid.c"
cp "$B/drivers/amlogic/media/vout/hdmitx21/hdmi_tx_main.c" "$D/hdmitx21_hdmi_tx_main.c"
cp "$B/include/linux/amlogic/media/vout/hdmi_tx21/hdmi_common.h" "$D/hdmitx21_hdmi_common.h"
cp "$B/include/linux/amlogic/media/vout/hdmi_tx21/hdmi_tx_module.h" "$D/hdmitx21_hdmi_tx_module.h"
cp "$B/include/linux/amlogic/media/vout/vinfo.h" "$D/vinfo.h"
ls -la "$D"
