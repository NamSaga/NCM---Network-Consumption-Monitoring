#!/bin/sh
# Network metadata snapshot for the Data Usage DankBar plugin.
# Prints one record per line, fields separated by '|':
#   IF|iface|physical(0/1)|wireless(0/1)|driver|operstate
#   RT|iface-of-default-route
#   BOOT|boot-id            UP|uptime-seconds
#   NM|<nmcli -t DEVICE:TYPE:STATE:CON-UUID:CONNECTION>
#   DEV|iface  MET|metered-state   (pairs, from nmcli device show)
#   CON|uuid|type|ipv4.method|wifi-mode|ssid
#   NONM|                    (NetworkManager not available)
export LC_ALL=C

for d in /sys/class/net/*; do
    i=${d##*/}
    phys=0; [ -e "$d/device" ] && phys=1
    wl=0; { [ -d "$d/wireless" ] || [ -d "$d/phy80211" ]; } && wl=1
    drv=""
    [ -e "$d/device/driver" ] && drv=$(basename "$(readlink -f "$d/device/driver")")
    op=$(cat "$d/operstate" 2>/dev/null)
    echo "IF|$i|$phys|$wl|$drv|$op"
done

rt=$(ip -o route show default 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit }}')
echo "RT|$rt"
echo "BOOT|$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)"
echo "UP|$(cut -d' ' -f1 /proc/uptime)"

if ! command -v nmcli >/dev/null 2>&1; then
    echo "NONM|"
    exit 0
fi

nmcli -t -f DEVICE,TYPE,STATE,CON-UUID,CONNECTION device status 2>/dev/null | sed 's/^/NM|/'
nmcli -t -f GENERAL.DEVICE,GENERAL.METERED device show 2>/dev/null |
    sed -n 's/^GENERAL\.DEVICE:/DEV|/p; s/^GENERAL\.METERED:/MET|/p'

nmcli -t -f UUID,TYPE connection show --active 2>/dev/null | while IFS= read -r line; do
    u=${line%%:*}
    t=${line#*:}
    case "$t" in
        802-11-wireless)
            nmcli -g 802-11-wireless.mode,ipv4.method,802-11-wireless.ssid connection show uuid "$u" 2>/dev/null |
                { read -r mode; read -r method; read -r ssid; echo "CON|$u|wifi|$method|$mode|$ssid"; }
            ;;
        *)
            echo "CON|$u|$t|$(nmcli -g ipv4.method connection show uuid "$u" 2>/dev/null)||"
            ;;
    esac
done
