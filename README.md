# NCM: Network Consumption Monitoring

**Data Usage**, a DankBar plugin for [DankMaterialShell](https://danklinux.com/docs/dankmaterialshell/overview). It tracks daily **download and upload** for **every network you use**: Wi‑Fi (including a phone's hotspot), Ethernet, USB tethering, Bluetooth tethering and mobile‑broadband modems. It also shows live speed in the bar and includes a fast.com‑style speed test.

## Features

- **Per‑network daily totals.** Each day is split by network (Wi‑Fi SSID, Ethernet connection, "Phone (USB tethering)", and so on), with ↓ and ↑ kept separate.
- **All interfaces at once.** If Wi‑Fi and Ethernet are both up, both are counted. Plugging in a phone over USB is picked up immediately through `nmcli monitor`.
- **Hourly chart.** Today's usage hour by hour, and the same for any past day in History. Hover a bar to see its numbers.
- **Data caps.** Set a daily, weekly or monthly cap (with a billing reset day) on any network or on all networks together. You get a desktop notification at 80% and 100%. The bar icon turns amber and then red.
- **Rename networks.** Click a network in the Networks tab to give it a friendlier name.
- **Per‑app usage.** Splits traffic by application from your TCP connections (`ss`). UDP/QUIC traffic, such as much video streaming and calls, is listed as "Not attributed" rather than guessed.
- **Speed test.** One‑click download, upload and latency test against Cloudflare's speed endpoints, with live speed while it runs and a list of recent results. The data it may use is capped (configurable) and you're warned on metered networks.
- **Hotspot‑aware.** When this machine *hosts* a hotspot, client traffic is shown separately and is **not** added to your total. That traffic already counts on your uplink, so adding it would count it twice.
- **Metered badge.** NetworkManager flags Android hotspots and USB tethering as metered automatically. The bar icon shows it.
- **CSV export and reset.** Export every day and network to `~/Downloads/data-usage-YYYY-MM-DD.csv`, or clear the history (asks for a second click).
- **No lost bytes on shell restart.** Raw interface counters and the boot ID are saved together, so the gap is recovered after `dms restart`.
- **Multi‑monitor safe.** One bar instance samples and the others only display, so nothing is counted twice.

## Install

```sh
git clone https://github.com/NamSaga/NCM---Network-Consumption-Monitoring.git ~/GitHub/ncm
ln -s ~/GitHub/ncm ~/.config/DankMaterialShell/plugins/dataUsage
dms ipc call plugins enable dataUsage
```
Then add **Data Usage** to a DankBar section in Settings. After pulling updates, run `dms restart`; a plugin reload does not pick up new QML files.

## Settings

| Setting | Default |
|---|---|
| Bar shows: live speed, data used today, or both | Live speed |
| Update interval | 2 s |
| Size units: decimal (GB, how carriers bill) or binary (GiB) | Decimal |
| Speed units: bytes or bits per second | Bytes |
| Track usage per app | On |
| Speed test data limit (download; upload gets a third) | 300 MB |
| Keep history for | 90 days |

## How it works

| What | Source |
|---|---|
| Byte counters (every *n* s) | `/proc/net/dev` |
| Interface → network, type, SSID, AP/shared mode, metered | `scripts/netmeta.sh` (sysfs + `nmcli`), re‑run on every `nmcli monitor` event and every 60 s |
| Per‑app bytes | `ss -tinpHe` (TCP `bytes_received` / `bytes_sent` per socket) |
| Speed test | `scripts/speedtest.sh`: curl against `speed.cloudflare.com` (`__down`, `__up`, `meta`) |
| Storage | `~/.local/state/DankMaterialShell/plugins/dataUsage_state.json`; names and caps live in the plugin settings |

Counted interfaces are physical devices (`/sys/class/net/*/device`) plus `ppp*`, `wwan*`, `bnep*`, `usb*` and `rmnet*`. Loopback, Docker, bridges, VPN tunnels and other virtual devices are skipped, because their traffic already passes through a physical interface.

Without NetworkManager, the plugin still works, but networks are labelled by interface name.

## Tips

- Mark a phone hotspot as metered if NM didn't guess it: `nmcli connection modify "<SSID>" connection.metered yes`.
- USB tethering is recognised by driver (`rndis_host`, `cdc_ncm`, `cdc_ether`, `ipheth`). A few USB‑C Ethernet docks use the same drivers and will show as "Phone (USB tethering)"; rename them in the Networks tab.
