import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "data-usage"

    // ───────────────────────────── Settings ─────────────────────────────
    readonly property int updateInterval: Math.max(1, Number(pluginData.updateInterval) || 2)
    readonly property string pillMode: pluginData.pillMode || "speed"          // speed | today | both
    readonly property bool decimalUnits: (pluginData.unitBase || "decimal") === "decimal"
    readonly property bool bitsSpeed: (pluginData.speedUnit || "bytes") === "bits"
    readonly property int retentionDays: Math.max(7, Number(pluginData.retentionDays) || 90)
    readonly property var aliases: pluginData.aliases || ({})   // netKey -> custom name
    readonly property var caps: pluginData.caps || ({})         // netKey | "__all__" -> { limit, period, resetDay }

    // ─────────────────── Shared view state (all bar instances) ───────────────────
    // One instance (the "leader") samples counters and publishes into PluginService
    // global vars; every instance (one per bar/screen) renders from these, so traffic
    // is never counted twice when the widget is on several monitors.
    readonly property var g: (pluginId && PluginService.globalVars[pluginId]) ? PluginService.globalVars[pluginId] : ({})
    readonly property var live: g.live || ({})
    readonly property var store: g.store || ({})
    readonly property var nets: live.nets || store.networks || ({})
    readonly property var activeList: live.active || []
    readonly property bool online: live.online === true
    readonly property var primaryConn: {
        const a = activeList.filter(x => x.kind !== "sharing");
        return a.find(x => x.primary) || a[0] || null;
    }
    readonly property var todayTotals: sumDay(live.today || {})
    readonly property real todayTotal: todayTotals.rx + todayTotals.tx

    // UI state
    property string tab: "today"
    readonly property var tabs: [["today", "Today"], ["history", "History"], ["networks", "Networks"]]
    property string expandedDay: ""
    property int netPeriod: 30            // 7 | 30 | 0 (all)
    property string editingKey: ""        // network whose editor is open

    // ─────────────────────────── Formatting ───────────────────────────
    function fmtBytes(b) {
        b = Math.max(0, b || 0);
        const k = decimalUnits ? 1000 : 1024;
        const u = decimalUnits ? ["B", "KB", "MB", "GB", "TB"] : ["B", "KiB", "MiB", "GiB", "TiB"];
        let i = 0;
        while (b >= k && i < u.length - 1) {
            b /= k;
            i++;
        }
        const s = i === 0 ? b.toFixed(0) : b < 10 ? b.toFixed(2) : b < 100 ? b.toFixed(1) : b.toFixed(0);
        return s + " " + u[i];
    }

    function fmtSpeed(bps) {
        bps = Math.max(0, bps || 0);
        if (bitsSpeed) {
            let v = bps * 8, i = 0;
            const u = ["b/s", "Kb/s", "Mb/s", "Gb/s"];
            while (v >= 1000 && i < u.length - 1) {
                v /= 1000;
                i++;
            }
            return (i === 0 ? v.toFixed(0) : v.toFixed(1)) + " " + u[i];
        }
        const k = decimalUnits ? 1000 : 1024;
        const u = decimalUnits ? ["B/s", "KB/s", "MB/s", "GB/s"] : ["B/s", "KiB/s", "MiB/s", "GiB/s"];
        let v = bps, i = 0;
        while (v >= k && i < u.length - 1) {
            v /= k;
            i++;
        }
        return (i === 0 ? v.toFixed(0) : v.toFixed(1)) + " " + u[i];
    }

    // Narrow form for vertical bars: "1.2M", "340K"
    function fmtShort(n) {
        n = Math.max(0, n || 0);
        if (bitsSpeed)
            n *= 8;
        const k = decimalUnits || bitsSpeed ? 1000 : 1024;
        const u = ["", "K", "M", "G", "T"];
        let i = 0;
        while (n >= k && i < u.length - 1) {
            n /= k;
            i++;
        }
        return (n < 10 && i > 0 ? n.toFixed(1) : n.toFixed(0)) + u[i];
    }

    function dateKey(d) {
        return Qt.formatDate(d || new Date(), "yyyy-MM-dd");
    }

    function dayLabel(key) {
        const today = dateKey();
        const y = new Date();
        y.setDate(y.getDate() - 1);
        if (key === today)
            return "Today";
        if (key === dateKey(y))
            return "Yesterday";
        return Qt.formatDate(new Date(key + "T00:00:00"), "ddd d MMM");
    }

    function kindIcon(k) {
        switch (k) {
        case "all":
            return "public";
        case "wifi":
            return "wifi";
        case "ethernet":
            return "lan";
        case "tether":
            return "usb";
        case "cellular":
            return "signal_cellular_alt";
        case "bluetooth":
            return "bluetooth";
        case "sharing":
            return "wifi_tethering";
        case "legacy":
            return "history";
        default:
            return "settings_ethernet";
        }
    }

    function kindName(k) {
        switch (k) {
        case "all":
            return "Everything except hotspot sharing";
        case "wifi":
            return "Wi-Fi";
        case "ethernet":
            return "Ethernet";
        case "tether":
            return "USB tethering";
        case "cellular":
            return "Mobile data";
        case "bluetooth":
            return "Bluetooth tethering";
        case "sharing":
            return "Your hotspot · shared to clients";
        case "legacy":
            return "Imported from Network Indicator";
        default:
            return "Other";
        }
    }

    function netInfo(key) {
        const n = nets[key] || {
            label: key,
            kind: "other"
        };
        if (!aliases[key])
            return n;
        return Object.assign({}, n, {
            label: aliases[key],
            origLabel: n.label
        });
    }

    function labelFor(key, fallback) {
        return aliases[key] || fallback || netInfo(key).label;
    }

    // Shared through plugin settings, so every bar instance sees the change.
    function setAlias(key, name) {
        const a = Object.assign({}, aliases);
        const orig = (nets[key] || {}).label || "";
        name = (name || "").trim();
        if (name && name !== orig)
            a[key] = name;
        else
            delete a[key];
        PluginService.savePluginData(pluginId, "aliases", a);
    }

    // ─────────────────────────── Aggregation ───────────────────────────
    // Consumption excludes "sharing" interfaces: what clients pull through your
    // hotspot is already counted on your uplink (Ethernet, phone, ...).
    function sumDay(day) {
        let rx = 0, tx = 0, srx = 0, stx = 0;
        for (const k in day) {
            const e = day[k];
            if (netInfo(k).kind === "sharing") {
                srx += e[0];
                stx += e[1];
            } else {
                rx += e[0];
                tx += e[1];
            }
        }
        return {
            rx: rx,
            tx: tx,
            sharedRx: srx,
            sharedTx: stx
        };
    }

    function allDays() {
        const d = Object.assign({}, store.days || {});
        if (live.day)
            d[live.day] = live.today || {};
        return d;
    }

    function dayRows(day) {
        const rows = [];
        for (const k in day) {
            const e = day[k];
            if (e[0] + e[1] <= 0)
                continue;
            const n = netInfo(k);
            rows.push({
                key: k,
                label: n.label,
                origLabel: n.origLabel || "",
                kind: n.kind,
                metered: !!n.metered,
                rx: e[0],
                tx: e[1],
                total: e[0] + e[1]
            });
        }
        rows.sort((a, b) => (a.kind === "sharing") - (b.kind === "sharing") || b.total - a.total);
        return rows;
    }

    function hoursFor(day) {
        if (day === live.day)
            return live.hours || [];
        return (store.hours || {})[day] || [];
    }

    function historyRows() {
        const d = allDays();
        return Object.keys(d).sort().reverse().map(k => {
            const s = sumDay(d[k]);
            return {
                date: k,
                rx: s.rx,
                tx: s.tx,
                total: s.rx + s.tx,
                nets: dayRows(d[k])
            };
        });
    }

    function periodTotals() {
        const d = allDays();
        const now = new Date();
        const c7 = new Date(now), c30 = new Date(now);
        c7.setDate(now.getDate() - 6);
        c30.setDate(now.getDate() - 29);
        const k7 = dateKey(c7), k30 = dateKey(c30), month = dateKey(now).slice(0, 7);
        const r = {
            week: 0,
            days30: 0,
            month: 0
        };
        for (const k in d) {
            const s = sumDay(d[k]);
            const t = s.rx + s.tx;
            if (k >= k7)
                r.week += t;
            if (k >= k30)
                r.days30 += t;
            if (k.slice(0, 7) === month)
                r.month += t;
        }
        return r;
    }

    function networkRows(period) {
        const d = allDays();
        let cutoff = "";
        if (period > 0) {
            const c = new Date();
            c.setDate(c.getDate() - (period - 1));
            cutoff = dateKey(c);
        }
        const acc = {};
        for (const day in d) {
            if (day < cutoff)
                continue;
            for (const k in d[day]) {
                const e = d[day][k];
                if (e[0] + e[1] <= 0)
                    continue;
                const a = acc[k] || (acc[k] = {
                        key: k,
                        rx: 0,
                        tx: 0,
                        days: 0,
                        last: ""
                    });
                a.rx += e[0];
                a.tx += e[1];
                a.days++;
                if (day > a.last)
                    a.last = day;
            }
        }
        const rows = Object.values(acc).map(a => {
            const n = netInfo(a.key);
            a.label = n.label;
            a.origLabel = n.origLabel || "";
            a.kind = n.kind;
            a.metered = !!n.metered;
            a.total = a.rx + a.tx;
            return a;
        });
        rows.sort((a, b) => (a.kind === "sharing") - (b.kind === "sharing") || b.total - a.total);
        return rows;
    }

    // ───────────────────────────── Data caps ─────────────────────────────
    function daysInMonth(y, m) {
        return new Date(y, m + 1, 0).getDate();
    }

    // Current billing cycle for a cap: { start, end, daysLeft } (end is exclusive)
    function cycleBounds(cap, now) {
        now = now || new Date();
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        let start, end;
        if (cap.period === "day") {
            start = today;
            end = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1);
        } else if (cap.period === "week") {
            const dow = (today.getDay() + 6) % 7; // Monday = 0
            start = new Date(today.getFullYear(), today.getMonth(), today.getDate() - dow);
            end = new Date(start.getFullYear(), start.getMonth(), start.getDate() + 7);
        } else {
            const d = Math.max(1, Math.min(31, cap.resetDay || 1));
            let y = today.getFullYear(), m = today.getMonth();
            if (today.getDate() < Math.min(d, daysInMonth(y, m))) {
                m--;
                if (m < 0) {
                    m = 11;
                    y--;
                }
            }
            start = new Date(y, m, Math.min(d, daysInMonth(y, m)));
            let ny = y, nm = m + 1;
            if (nm > 11) {
                nm = 0;
                ny++;
            }
            end = new Date(ny, nm, Math.min(d, daysInMonth(ny, nm)));
        }
        return {
            start: dateKey(start),
            end: dateKey(end),
            endDate: end,
            daysLeft: Math.round((end - today) / 86400000)
        };
    }

    function usedSince(daysObj, key, startKey) {
        let t = 0;
        for (const d in daysObj) {
            if (d < startKey)
                continue;
            const day = daysObj[d];
            if (key === "__all__") {
                const s = sumDay(day);
                t += s.rx + s.tx;
            } else if (day[key]) {
                t += day[key][0] + day[key][1];
            }
        }
        return t;
    }

    function capStatus(key, daysObj) {
        const cap = caps[key];
        if (!cap || !(cap.limit > 0))
            return null;
        const b = cycleBounds(cap);
        const used = usedSince(daysObj || allDays(), key, b.start);
        const pct = used / cap.limit;
        return {
            key: key,
            label: key === "__all__" ? "All networks" : netInfo(key).label,
            cap: cap,
            used: used,
            pct: pct,
            level: pct >= 1 ? 100 : pct >= 0.8 ? 80 : 0,
            start: b.start,
            end: b.end,
            endDate: b.endDate,
            daysLeft: b.daysLeft
        };
    }

    function setCap(key, cap) {
        const c = Object.assign({}, caps);
        if (cap && cap.limit > 0)
            c[key] = cap;
        else
            delete c[key];
        PluginService.savePluginData(pluginId, "caps", c);
    }

    function periodName(p) {
        return p === "day" ? "Daily" : p === "week" ? "Weekly" : "Monthly";
    }

    // Caps that matter right now: the overall cap plus caps on active networks.
    readonly property var activeCaps: {
        const keys = Object.keys(caps);
        if (keys.length === 0)
            return [];
        const activeKeys = activeList.filter(a => a.kind !== "sharing").map(a => a.key);
        const d = allDays();
        const out = [];
        for (const k of keys) {
            if (k !== "__all__" && activeKeys.indexOf(k) < 0)
                continue;
            const st = capStatus(k, d);
            if (st)
                out.push(st);
        }
        out.sort((a, b) => b.pct - a.pct);
        return out;
    }
    readonly property int capLevel: activeCaps.length > 0 ? activeCaps[0].level : 0

    function maxOf(rows) {
        let m = 1;
        for (const r of rows)
            if (r.total > m)
                m = r.total;
        return m;
    }

    // ═════════════════════════ Leader: data collection ═════════════════════════
    readonly property string instanceId: Math.random().toString(36).slice(2, 10)
    property bool isLeader: false
    property bool stateLoaded: false
    property bool metaReady: false
    property bool firstSampleDone: false
    property bool dirty: false

    property var days: ({})          // "yyyy-MM-dd" -> { netKey: [rx, tx] }
    property var hours: ({})         // "yyyy-MM-dd" -> [[rx, tx] × 24], consumption only
    property var networks: ({})      // netKey -> { label, kind, metered, iface, last }
    property var ifaceMap: ({})      // iface -> { counted, connected, key, label, kind, metered, primary }
    property var lastCounters: ({})  // iface -> [rx, tx]
    property var savedCounters: ({}) // from disk: iface -> [rx, tx, key]
    property var capAlerts: ({})     // netKey -> { cycle, limit, level } last notified level
    property string savedBootId: ""
    property string bootId: ""
    property real uptime: 0
    property string currentDay: ""
    property real lastSampleAt: 0
    property real downSpeed: 0
    property real upSpeed: 0

    readonly property string scriptPath: decodeURIComponent(Qt.resolvedUrl("scripts/netmeta.sh").toString().replace(/^file:\/\//, ""))
    readonly property int staleMs: Math.max(10000, updateInterval * 4000)

    function deepCopy(o) {
        return JSON.parse(JSON.stringify(o === undefined ? null : o));
    }

    function checkLeader() {
        if (!pluginId)
            return;
        const l = PluginService.getGlobalVar(pluginId, "live", null);
        const now = Date.now();
        if (isLeader) {
            if (l && l.leader && l.leader !== instanceId && now - (l.beat || 0) < staleMs)
                isLeader = false; // someone else took over; stop sampling
            return;
        }
        if (!l || !l.leader || now - (l.beat || 0) > staleMs)
            becomeLeader();
    }

    function becomeLeader() {
        isLeader = true;
        loadState();
        publishLive();
        publishStore();
        metaProc.running = true;
        monitorProc.running = true;
    }

    function loadState() {
        const storedDays = PluginService.loadPluginState(pluginId, "days", null);
        days = deepCopy(storedDays || {}) || {};
        networks = deepCopy(PluginService.loadPluginState(pluginId, "networks", {})) || {};
        hours = deepCopy(PluginService.loadPluginState(pluginId, "hours", {})) || {};
        capAlerts = deepCopy(PluginService.loadPluginState(pluginId, "capAlerts", {})) || {};
        savedCounters = deepCopy(PluginService.loadPluginState(pluginId, "counters", {})) || {};
        savedBootId = PluginService.loadPluginState(pluginId, "bootId", "") || "";
        if (!storedDays)
            importLegacy();
        currentDay = dateKey();
        firstSampleDone = false;
        lastCounters = {};
        lastSampleAt = 0;
        stateLoaded = true;
    }

    // One-time import of the old "networkIndicator" plugin's daily totals.
    function importLegacy() {
        const old = PluginService.loadPluginState("networkIndicator", "days", null);
        if (!old)
            return;
        let n = 0;
        for (const day in old) {
            const e = old[day] || {};
            if ((e.rx || 0) + (e.tx || 0) <= 0)
                continue;
            days[day] = {
                "legacy": [e.rx || 0, e.tx || 0]
            };
            n++;
        }
        if (n > 0) {
            networks["legacy"] = {
                label: "Before per-network tracking",
                kind: "legacy"
            };
            console.info("DataUsage: imported", n, "day(s) from Network Indicator");
            dirty = true;
        }
    }

    function pruneDays() {
        const c = new Date();
        c.setDate(c.getDate() - Math.max(retentionDays, 32)); // keep a full monthly cap cycle
        const cutoff = dateKey(c);
        for (const k of Object.keys(days))
            if (k < cutoff)
                delete days[k];
        for (const k of Object.keys(hours))
            if (k < cutoff)
                delete hours[k];
    }

    function saveState() {
        if (!isLeader || !stateLoaded)
            return;
        pruneDays();
        const counters = {};
        for (const n in lastCounters)
            counters[n] = [lastCounters[n][0], lastCounters[n][1], (ifaceMap[n] || {}).key || ""];
        PluginService.savePluginState(pluginId, "version", 1);
        PluginService.savePluginState(pluginId, "days", deepCopy(days));
        PluginService.savePluginState(pluginId, "hours", deepCopy(hours));
        PluginService.savePluginState(pluginId, "networks", deepCopy(networks));
        if (firstSampleDone) {
            PluginService.savePluginState(pluginId, "counters", counters);
            PluginService.savePluginState(pluginId, "bootId", bootId);
        }
        PluginService.savePluginState(pluginId, "savedAt", Date.now());
        dirty = false;
        publishStore();
    }

    function publishStore() {
        if (!pluginId)
            return;
        PluginService.setGlobalVar(pluginId, "store", {
            days: deepCopy(days),
            hours: deepCopy(hours),
            networks: deepCopy(networks)
        });
    }

    function publishLive() {
        if (!pluginId || !isLeader)
            return;
        const active = [];
        for (const name in ifaceMap) {
            const i = ifaceMap[name];
            if (i.counted && i.connected)
                active.push({
                    iface: name,
                    key: i.key,
                    label: i.label,
                    kind: i.kind,
                    metered: i.metered,
                    primary: i.primary
                });
        }
        active.sort((a, b) => (a.kind === "sharing") - (b.kind === "sharing") || (b.primary - a.primary));
        PluginService.setGlobalVar(pluginId, "live", {
            leader: instanceId,
            beat: Date.now(),
            down: downSpeed,
            up: upSpeed,
            online: active.some(a => a.kind !== "sharing"),
            active: active,
            day: currentDay,
            today: deepCopy(days[currentDay] || {}),
            hours: deepCopy(hours[currentDay] || []),
            nets: deepCopy(networks)
        });
    }

    function addUsage(day, key, info, rx, tx) {
        const b = days[day] || (days[day] = {});
        const e = b[key] || (b[key] = [0, 0]);
        e[0] += rx;
        e[1] += tx;
        if (!networks[key])
            networks[key] = {
                label: info.label,
                kind: info.kind,
                metered: info.metered,
                iface: info.iface || "",
                last: day
            };
    }

    function addHourly(day, hour, rx, tx) {
        let h = hours[day];
        if (!h || h.length !== 24) {
            h = [];
            for (let i = 0; i < 24; i++)
                h.push([0, 0]);
            hours[day] = h;
        }
        h[hour][0] += rx;
        h[hour][1] += tx;
    }

    // Notify once per cycle when a cap crosses 80% and again at 100%.
    function checkCaps() {
        if (!isLeader || !firstSampleDone)
            return;
        let changed = false;
        for (const key in caps) {
            const st = capStatus(key, days);
            if (!st)
                continue;
            const prev = capAlerts[key];
            const sameCycle = prev && prev.cycle === st.start && prev.limit === st.cap.limit;
            const prevLevel = sameCycle ? prev.level : 0;
            if (st.level > prevLevel)
                notifyCap(st);
            if (!sameCycle || st.level > prevLevel) {
                capAlerts[key] = {
                    cycle: st.start,
                    limit: st.cap.limit,
                    level: Math.max(st.level, prevLevel)
                };
                changed = true;
            }
        }
        for (const k of Object.keys(capAlerts)) {
            if (!caps[k]) {
                delete capAlerts[k];
                changed = true;
            }
        }
        if (changed)
            PluginService.savePluginState(pluginId, "capAlerts", deepCopy(capAlerts));
    }

    function notifyCap(st) {
        const over = st.level >= 100;
        const title = over ? "Data cap reached: " + st.label : st.label + ": " + Math.floor(st.pct * 100) + "% of data cap used";
        const span = st.cap.period === "day" ? "today" : st.cap.period === "week" ? "this week" : "this billing cycle";
        const resets = st.cap.period === "day" ? "Resets at midnight." : "Resets " + Qt.formatDate(st.endDate, "d MMM") + ".";
        const body = fmtBytes(st.used) + " of " + fmtBytes(st.cap.limit) + " used " + span + ". " + resets;
        Quickshell.execDetached(["notify-send", "-a", "Data Usage", "-u", over ? "critical" : "normal", "-i", "network-transmit-receive", title, body]);
    }

    // nmcli -t escapes ':' and '\' with a backslash
    function splitTerse(s) {
        const out = [];
        let cur = "";
        for (let i = 0; i < s.length; i++) {
            const ch = s[i];
            if (ch === "\\" && i + 1 < s.length) {
                cur += s[++i];
            } else if (ch === ":") {
                out.push(cur);
                cur = "";
            } else {
                cur += ch;
            }
        }
        out.push(cur);
        return out;
    }

    function unescapeNm(s) {
        return (s || "").replace(/\\(.)/g, "$1");
    }

    function onMeta(lines) {
        const ifs = {}, nm = {}, met = {}, cons = {};
        let route = "", curDev = "";
        for (const raw of lines) {
            const bar = raw.indexOf("|");
            if (bar < 0)
                continue;
            const tag = raw.slice(0, bar), rest = raw.slice(bar + 1);
            if (tag === "IF") {
                const p = rest.split("|");
                ifs[p[0]] = {
                    phys: p[1] === "1",
                    wireless: p[2] === "1",
                    driver: p[3] || "",
                    oper: p[4] || ""
                };
            } else if (tag === "RT") {
                route = rest.trim();
            } else if (tag === "BOOT") {
                bootId = rest.trim();
            } else if (tag === "UP") {
                uptime = parseFloat(rest) || 0;
            } else if (tag === "NM") {
                const p = splitTerse(rest);
                if (p.length >= 5)
                    nm[p[0]] = {
                        type: p[1],
                        state: p[2],
                        uuid: p[3],
                        conn: p.slice(4).join(":")
                    };
            } else if (tag === "DEV") {
                curDev = rest.trim();
            } else if (tag === "MET") {
                if (curDev)
                    met[curDev] = rest.trim();
            } else if (tag === "CON") {
                const p = rest.split("|");
                cons[p[0]] = {
                    type: p[1],
                    method: p[2] || "",
                    mode: p[3] || "",
                    ssid: unescapeNm(p.slice(4).join("|"))
                };
            }
        }

        const today = dateKey();
        const prevMap = ifaceMap;
        const map = {};
        for (const name in ifs) {
            const f = ifs[name];
            const counted = name !== "lo" && !name.startsWith("p2p-") && (f.phys || /^(ppp|wwan|ww|bnep|usb|rmnet)/.test(name));
            const d = nm[name];
            const c = d && d.uuid ? cons[d.uuid] : null;
            const connected = d ? /^connected/.test(d.state) : f.oper === "up";
            const type = d ? d.type : (f.wireless ? "wifi" : f.phys ? "ethernet" : "");
            const conn = d ? d.conn : "";
            const shared = !!c && c.method === "shared";
            let kind = "other", label = name, key = "if:" + name;

            if (type === "wifi") {
                const ssid = c ? c.ssid : "";
                if (c && (c.mode === "ap" || shared)) {
                    kind = "sharing";
                    label = "Hotspot · " + (ssid || conn || name);
                    key = "share:" + (ssid || conn || name);
                } else {
                    kind = "wifi";
                    if (connected && (ssid || conn)) {
                        label = ssid || conn;
                        key = "wifi:" + label;
                    }
                }
            } else if (type === "ethernet") {
                const drv = f.driver;
                if (shared) {
                    kind = "sharing";
                    label = "Shared · " + (conn || name);
                    key = "share:" + (conn || name);
                } else if (drv === "ipheth") {
                    kind = "tether";
                    label = "iPhone (USB tethering)";
                    key = "tether:iphone";
                } else if (["rndis_host", "cdc_ether", "cdc_ncm", "cdc_eem"].indexOf(drv) >= 0) {
                    kind = "tether";
                    label = "Phone (USB tethering)";
                    key = "tether:usb";
                } else {
                    kind = "ethernet";
                    if (connected && conn) {
                        label = conn;
                        key = "eth:" + conn;
                    }
                }
            } else if (["gsm", "cdma", "modem", "wwan"].indexOf(type) >= 0 || /^(wwan|ww|rmnet|ppp)/.test(name)) {
                kind = "cellular";
                label = conn || "Mobile data";
                key = "cell:" + label;
            } else if (type === "bt" || name.startsWith("bnep")) {
                kind = "bluetooth";
                label = conn || "Bluetooth tethering";
                key = "bt:" + label;
            }

            // While disconnected/switching, keep attributing stray bytes to the last network.
            if (!connected && prevMap[name] && prevMap[name].key) {
                key = prevMap[name].key;
                label = prevMap[name].label;
                kind = prevMap[name].kind;
            }

            const metered = (met[name] || "").startsWith("yes");
            map[name] = {
                iface: name,
                counted: counted,
                connected: connected,
                kind: kind,
                label: label,
                key: key,
                metered: metered,
                primary: name === route
            };
            if (counted && connected) {
                const n = networks[key] || {};
                networks[key] = {
                    label: label,
                    kind: kind,
                    metered: metered || !!n.metered,
                    iface: name,
                    last: today
                };
            }
        }
        ifaceMap = map;

        if (!metaReady) {
            metaReady = true;
            counterProc.running = true;
        } else {
            publishLive();
        }
    }

    function onCounters(lines) {
        const cur = {};
        for (const line of lines) {
            const idx = line.indexOf(":");
            if (idx < 0)
                continue;
            const name = line.slice(0, idx).trim();
            const f = line.slice(idx + 1).trim().split(/\s+/);
            if (!name || f.length < 9)
                continue;
            cur[name] = [Number(f[0]) || 0, Number(f[8]) || 0];
        }

        const now = Date.now();
        const today = dateKey();
        if (today !== currentDay) {
            saveState();
            currentDay = today;
        }

        // Gap recovery on the first sample after (re)start
        let recovery = "";
        if (!firstSampleDone) {
            if (savedBootId && savedBootId === bootId)
                recovery = "same-boot";        // shell restarted: add bytes since last save
            else if (savedBootId !== bootId && uptime < 900)
                recovery = "fresh-boot";       // just booted: add bytes since boot
        }

        let dRx = 0, dTx = 0, needMeta = false;
        const next = {};
        for (const name in cur) {
            const info = ifaceMap[name];
            if (!info) {
                if (name !== "lo")
                    needMeta = true; // new interface: classify it first, count it next sample
                continue;
            }
            if (!info.counted)
                continue;
            const c = cur[name], p = lastCounters[name];
            next[name] = c;
            let rx = 0, tx = 0, key = info.key;
            if (!firstSampleDone) {
                const s = savedCounters[name];
                if (recovery === "same-boot") {
                    if (s && c[0] >= s[0] && c[1] >= s[1]) {
                        rx = c[0] - s[0];
                        tx = c[1] - s[1];
                        if (s[2])
                            key = s[2];
                    } else if (!s) {
                        rx = c[0];
                        tx = c[1];
                    }
                } else if (recovery === "fresh-boot") {
                    rx = c[0];
                    tx = c[1];
                }
            } else if (!p) {
                rx = c[0];       // interface appeared since last sample: counters start at 0
                tx = c[1];
            } else {
                rx = c[0] >= p[0] ? c[0] - p[0] : c[0];   // counter reset → bytes since reset
                tx = c[1] >= p[1] ? c[1] - p[1] : c[1];
            }
            if (rx > 1e12 || tx > 1e12)
                continue; // implausible jump, ignore
            if (rx > 0 || tx > 0) {
                addUsage(currentDay, key, info, rx, tx);
                if ((networks[key] || info).kind !== "sharing") {
                    dRx += rx;
                    dTx += tx;
                    addHourly(currentDay, new Date(now).getHours(), rx, tx);
                }
            }
        }

        if (firstSampleDone && lastSampleAt > 0) {
            const el = (now - lastSampleAt) / 1000;
            downSpeed = el > 0.2 ? dRx / el : 0;
            upSpeed = el > 0.2 ? dTx / el : 0;
        } else {
            downSpeed = 0;
            upSpeed = 0;
        }
        lastCounters = next;
        lastSampleAt = now;

        if (!firstSampleDone) {
            firstSampleDone = true;
            saveState();
        } else if (dRx > 0 || dTx > 0) {
            dirty = true;
        }
        if (needMeta)
            metaDebounce.restart();
        publishLive();
    }

    // ── Timers & processes ──
    Timer {
        id: electionTimer
        interval: 3000
        repeat: true
        triggeredOnStart: true
        running: !!root.pluginId
        onTriggered: root.checkLeader()
    }

    Timer {
        id: sampleTimer
        interval: root.updateInterval * 1000
        repeat: true
        running: root.isLeader && root.metaReady
        onTriggered: counterProc.running = true
    }

    Timer {
        id: metaTimer
        interval: 60000
        repeat: true
        running: root.isLeader
        onTriggered: metaProc.running = true
    }

    Timer {
        id: metaDebounce
        interval: 1500
        onTriggered: if (root.isLeader)
            metaProc.running = true
    }

    Timer {
        id: saveTimer
        interval: 30000
        repeat: true
        running: root.isLeader
        onTriggered: if (root.dirty)
            root.saveState()
    }

    Timer {
        id: capTimer
        interval: 20000
        repeat: true
        triggeredOnStart: true
        running: root.isLeader && root.firstSampleDone
        onTriggered: root.checkCaps()
    }

    Timer {
        id: monitorRestart
        interval: 15000
        onTriggered: if (root.isLeader)
            monitorProc.running = true
    }

    Process {
        id: counterProc
        property var buf: []
        command: ["cat", "/proc/net/dev"]
        onStarted: buf = []
        stdout: SplitParser {
            onRead: line => counterProc.buf.push(line)
        }
        onExited: if (root.isLeader)
            root.onCounters(buf)
    }

    Process {
        id: metaProc
        property var buf: []
        command: ["sh", root.scriptPath]
        onStarted: buf = []
        stdout: SplitParser {
            onRead: line => metaProc.buf.push(line)
        }
        onExited: if (root.isLeader)
            root.onMeta(buf)
    }

    // React immediately when NetworkManager reports any change (plug/unplug, SSID switch…)
    Process {
        id: monitorProc
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: line => metaDebounce.restart()
        }
        onExited: if (root.isLeader)
            monitorRestart.start()
    }

    Component.onDestruction: {
        if (isLeader) {
            saveState();
            PluginService.setGlobalVar(pluginId, "live", Object.assign({}, live, {
                leader: "",
                beat: 0
            }));
        }
    }

    // ═════════════════════════════ Bar pills ═════════════════════════════
    readonly property string pillIcon: !online ? "cloud_off" : kindIcon(primaryConn ? primaryConn.kind : "other")
    readonly property color pillIconColor: {
        if (!online)
            return Theme.surfaceVariantText;
        if (capLevel >= 100)
            return Theme.error;
        if (capLevel >= 80 || (primaryConn && primaryConn.metered))
            return Theme.warning;
        return Theme.surfaceText;
    }
    readonly property color downColor: Theme.primary
    readonly property color upColor: Theme.error

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                name: root.pillIcon
                size: root.iconSize
                color: root.pillIconColor
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                id: speedProbe
                visible: false
                text: root.bitsSpeed ? "888.8 Mb/s" : root.decimalUnits ? "888.8 KB/s" : "888.8 KiB/s"
                font.pixelSize: Theme.fontSizeSmall
            }

            Row {
                visible: root.pillMode !== "today"
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    text: "↓"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Bold
                    color: root.downColor
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: root.fmtSpeed(root.live.down)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    width: Math.max(implicitWidth, speedProbe.implicitWidth)
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: "↑"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Bold
                    color: root.upColor
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: root.fmtSpeed(root.live.up)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    width: Math.max(implicitWidth, speedProbe.implicitWidth)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StyledText {
                visible: root.pillMode !== "speed"
                text: (root.pillMode === "both" ? "· " : "") + root.fmtBytes(root.todayTotal)
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: 1

            DankIcon {
                name: root.pillIcon
                size: root.iconSize
                color: root.pillIconColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
            StyledText {
                visible: root.pillMode !== "today"
                text: "↓" + root.fmtShort(root.live.down)
                font.pixelSize: Theme.fontSizeSmall - 1
                color: root.downColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
            StyledText {
                visible: root.pillMode !== "today"
                text: "↑" + root.fmtShort(root.live.up)
                font.pixelSize: Theme.fontSizeSmall - 1
                color: root.upColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
            StyledText {
                visible: root.pillMode !== "speed"
                text: root.fmtShort(root.todayTotal).replace(/([KMGT])$/, "$1B")
                font.pixelSize: Theme.fontSizeSmall - 1
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // ═════════════════════════════ Popout ═════════════════════════════
    popoutWidth: 400

    popoutContent: Component {
        PopoutComponent {
            id: pop
            showCloseButton: false

            Column {
                id: body
                width: pop.width
                spacing: Theme.spacingM

                // ── Header ──
                Column {
                    width: parent.width - Theme.spacingM * 2
                    x: Theme.spacingM
                    spacing: Theme.spacingS

                    StyledText {
                        text: "Data Usage"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                    }

                    Flow {
                        width: parent.width
                        spacing: Theme.spacingXS

                        StyledText {
                            visible: !root.online
                            text: "Offline: no active network"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.error
                        }

                        Repeater {
                            model: root.activeList
                            delegate: Rectangle {
                                required property var modelData
                                readonly property color tone: modelData.kind === "sharing" ? Theme.surfaceVariantText : modelData.metered ? Theme.warning : Theme.primary
                                height: 26
                                width: chipRow.implicitWidth + Theme.spacingS * 2
                                radius: 13
                                color: Theme.withAlpha(tone, modelData.kind === "sharing" ? 0.1 : 0.15)
                                Row {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    DankIcon {
                                        name: root.kindIcon(modelData.kind)
                                        size: 14
                                        color: tone
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    StyledText {
                                        text: root.labelFor(modelData.key, modelData.label) + (modelData.metered ? " · metered" : "")
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        font.weight: modelData.primary ? Font.Bold : Font.Normal
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Live speed ──
                Row {
                    width: parent.width - Theme.spacingM * 2
                    x: Theme.spacingM
                    spacing: Theme.spacingS

                    Repeater {
                        model: [
                            {
                                icon: "download",
                                label: "Download",
                                up: false
                            },
                            {
                                icon: "upload",
                                label: "Upload",
                                up: true
                            }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property color tone: modelData.up ? root.upColor : root.downColor
                            width: (parent.width - Theme.spacingS) / 2
                            height: 58
                            radius: Theme.cornerRadius
                            color: Theme.withAlpha(tone, 0.14)
                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingS
                                DankIcon {
                                    name: modelData.icon
                                    size: 22
                                    color: tone
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    StyledText {
                                        text: root.fmtSpeed(modelData.up ? root.live.up : root.live.down)
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Bold
                                        color: tone
                                    }
                                    StyledText {
                                        text: modelData.label + " now"
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        color: Theme.surfaceVariantText
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Tabs ──
                Row {
                    x: Theme.spacingM
                    spacing: Theme.spacingXS
                    Repeater {
                        model: root.tabs
                        delegate: Chip {
                            required property var modelData
                            label: modelData[1]
                            selected: root.tab === modelData[0]
                            onClicked: root.tab = modelData[0]
                        }
                    }
                }

                TodayTab {
                    host: root
                    visible: root.tab === "today"
                    width: parent.width - Theme.spacingM * 2
                    x: Theme.spacingM
                }

                HistoryTab {
                    host: root
                    visible: root.tab === "history"
                    width: parent.width - Theme.spacingM * 2
                    x: Theme.spacingM
                }

                NetworksTab {
                    host: root
                    visible: root.tab === "networks"
                    width: parent.width - Theme.spacingM * 2
                    x: Theme.spacingM
                }

                // ── Legend ──
                Row {
                    x: Theme.spacingM
                    spacing: Theme.spacingM
                    Repeater {
                        model: [["Download", root.downColor], ["Upload", root.upColor]]
                        delegate: Row {
                            required property var modelData
                            spacing: 4
                            Rectangle {
                                width: 10
                                height: 10
                                radius: 5
                                color: modelData[1]
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            StyledText {
                                text: modelData[0]
                                font.pixelSize: Theme.fontSizeSmall - 2
                                color: Theme.surfaceVariantText
                            }
                        }
                    }
                }
            }
        }
    }
}
