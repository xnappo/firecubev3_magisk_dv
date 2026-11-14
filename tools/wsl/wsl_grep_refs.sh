#!/bin/bash
# Greps the extracted Amazon gazelle kernel tree for the DV/EDID structures and callers we need to hook.
B="$HOME/fcsrc/plat/kernel/amlogic/pop1g/5.4/common"
cd "$B" || exit 1
echo "=== callers of hdmitx21_edid_parse"
grep -rn "hdmitx21_edid_parse" drivers include | grep -v "^Binary"
echo "=== struct dv_info"
grep -rn "struct dv_info {" include drivers
echo "=== struct rx_cap / hdmitx_dev definitions"
grep -rn -e "^struct rx_cap {" -e "^struct hdmitx_dev {" include drivers
echo "=== dv_info consumers (vout_device->dv_info)"
grep -rn "dv_info" drivers/amlogic/media/vout/hdmitx21/hdmi_tx_main.c | head -40
echo "=== attach_to_vinfo"
grep -rn "edidinfo_attach_to_vinfo" drivers | head
