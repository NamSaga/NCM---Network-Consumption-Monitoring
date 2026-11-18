# Data Usage — DankBar plugin

Daily **download / upload** tracking for **every network you use**: Wi‑Fi (including a phone's hotspot), Ethernet, USB tethering, Bluetooth tethering and mobile‑broadband modems, plus live speed in the bar.

## Features

- **Per‑network daily totals.** Each day is split by network (Wi‑Fi SSID, Ethernet connection, "Phone (USB tethering)", and so on), with ↓ and ↑ kept separate.
- **All interfaces at once.** If Wi‑Fi and Ethernet are both up, both are counted. Plugging in a phone over USB is picked up immediately through `nmcli monitor`.
- **Hotspot‑aware.** When this machine *hosts* a hotspot (NetworkManager AP or "shared" mode), client traffic is shown as "Your hotspot · shared to clients" and is **not** added to the total. That traffic already counts on your uplink, so adding it would count it twice.
- **Metered badge.** NetworkManager flags Android hotspots and USB tethering as metered automatically. The bar icon turns to the warning color while you are on a metered network.
- **History.** Expandable per‑day breakdown, totals for the last 7 days, the last 30 days and the calendar month, and a per‑network ranking (7 days / 30 days / all).
- **No lost bytes on shell restart.** Raw interface counters and the boot ID are saved together, so the gap is recovered after `dms restart`. Traffic since boot is also recovered if the shell starts within 15 minutes of booting.
- **Multi‑monitor safe.** One bar instance samples and the others only display, so nothing is counted twice.
- **Imports history** from the old *Network Indicator* plugin on first run.

## Install

```sh
ln -s ~/GitHub/ncm ~/.config/DankMaterialShell/plugins/dataUsage
dms ipc call plugins enable dataUsage
```
Then add **Data Usage** to a DankBar section in Settings.

## How it works

| What | Source |
|---|---|
| Byte counters (every *n* s) | `/proc/net/dev` |
| Interface → network, type, SSID, AP/shared mode, metered | `scripts/netmeta.sh` (sysfs + `nmcli`), re‑run on every `nmcli monitor` event and every 60 s |
| Default route (primary connection) | `ip route show default` |
| Storage | DMS plugin state: `~/.local/state/DankMaterialShell/plugins/dataUsage_state.json` |

Counted interfaces are physical devices (`/sys/class/net/*/device`) plus `ppp*`, `wwan*`, `bnep*`, `usb*` and `rmnet*`. Loopback, Docker, bridges, VPN tunnels and other virtual devices are skipped, because their traffic already passes through a physical interface.

Without NetworkManager, the plugin still works, but networks are labelled by interface name.

## Tips

- Rename connections to get friendlier labels: `nmcli connection modify "Wired connection 1" connection.id "Home LAN"`.
- Mark a phone hotspot as metered if NM didn't guess it: `nmcli connection modify "<SSID>" connection.metered yes`.
# NCM---Network-Consumption-Monitoring
