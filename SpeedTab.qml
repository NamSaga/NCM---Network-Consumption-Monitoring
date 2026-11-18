import QtQuick
import qs.Common
import qs.Widgets

// fast.com-style speed test: one big download number, then latency and upload.
Column {
    id: tabRoot

    property var host
    readonly property bool active: visible && host.tab === "speed"
    readonly property var sp: host.speed || ({})
    readonly property bool running: sp.running === true
    readonly property string phase: sp.phase || ""
    readonly property bool hasResult: (sp.down || -1) >= 0
    readonly property bool metered: !!(host.primaryConn && host.primaryConn.metered)
    property bool confirmMetered: false

    // Big number: live download while measuring it, final download afterwards
    readonly property real bigValue: {
        if (running && phase === "download")
            return sp.live || 0;
        if ((sp.down || -1) >= 0)
            return sp.down;
        return 0;
    }
    property real shown: bigValue
    Behavior on shown {
        NumberAnimation {
            duration: 450
            easing.type: Easing.OutCubic
        }
    }

    function mbpsNumber(bps) {
        const m = Math.max(0, bps) * 8 / 1e6;
        return m >= 1000 ? (m / 1000).toFixed(2) : m < 10 ? m.toFixed(1) : m.toFixed(0);
    }

    function ago(t) {
        const m = Math.round((Date.now() - t) / 60000);
        if (m < 1)
            return "just now";
        if (m < 60)
            return m + " min ago";
        const h = Math.round(m / 60);
        if (h < 24)
            return h + " h ago";
        return Qt.formatDate(new Date(t), "d MMM");
    }

    function start() {
        if (metered && !confirmMetered) {
            confirmMetered = true;
            confirmTimer.restart();
            return;
        }
        confirmMetered = false;
        host.requestSpeedTest("start");
    }

    Timer {
        id: confirmTimer
        interval: 5000
        onTriggered: tabRoot.confirmMetered = false
    }

    spacing: Theme.spacingM

    // ── Big readout ──
    Rectangle {
        width: parent.width
        height: 150
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceVariantText, 0.08)

        Column {
            anchors.centerIn: parent
            spacing: 2

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    if (tabRoot.sp.error)
                        return tabRoot.sp.error;
                    if (tabRoot.running) {
                        if (tabRoot.phase === "ping" || tabRoot.phase === "starting")
                            return "Measuring latency…";
                        if (tabRoot.phase === "download")
                            return "Testing download…";
                        return "Testing upload…";
                    }
                    if (tabRoot.phase === "cancelled")
                        return "Test cancelled";
                    return tabRoot.hasResult ? "Your download speed" : "Test your connection speed";
                }
                font.pixelSize: Theme.fontSizeSmall
                color: tabRoot.sp.error ? Theme.error : Theme.surfaceVariantText
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                StyledText {
                    text: tabRoot.mbpsNumber(tabRoot.shown)
                    font.pixelSize: 52
                    font.weight: Font.Bold
                    color: (tabRoot.running && tabRoot.phase !== "download") || (!tabRoot.running && !tabRoot.hasResult) ? Theme.surfaceVariantText : Theme.surfaceText
                }
                StyledText {
                    anchors.baseline: parent.children[0].baseline
                    text: tabRoot.shown * 8 / 1e6 >= 1000 ? "Gbps" : "Mbps"
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.surfaceVariantText
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !!tabRoot.sp.network
                text: "on " + tabRoot.sp.network
                font.pixelSize: Theme.fontSizeSmall - 1
                color: Theme.surfaceVariantText
            }
        }
    }

    // ── Latency / upload / data used ──
    Row {
        width: parent.width
        spacing: Theme.spacingS

        StatTile {
            width: (parent.width - Theme.spacingS * 2) / 3
            title: (tabRoot.sp.jitter || -1) >= 0 ? "Latency · ±" + Math.round(tabRoot.sp.jitter) + " ms" : "Latency"
            value: (tabRoot.sp.ping || -1) >= 0 ? Math.round(tabRoot.sp.ping) + " ms" : "–"
        }
        StatTile {
            width: (parent.width - Theme.spacingS * 2) / 3
            title: "Upload"
            valueColor: tabRoot.running && tabRoot.phase === "upload" ? Theme.surfaceVariantText : Theme.surfaceText
            value: {
                if (tabRoot.running && tabRoot.phase === "upload")
                    return tabRoot.host.fmtMbps(tabRoot.sp.live || 0);
                return (tabRoot.sp.up || -1) >= 0 ? tabRoot.host.fmtMbps(tabRoot.sp.up) : "–";
            }
        }
        StatTile {
            width: (parent.width - Theme.spacingS * 2) / 3
            title: "Data used"
            value: (tabRoot.sp.usedDown || 0) + (tabRoot.sp.usedUp || 0) > 0 ? tabRoot.host.fmtBytes(tabRoot.sp.usedDown + tabRoot.sp.usedUp) : "–"
        }
    }

    StyledText {
        visible: !!tabRoot.sp.server || !!tabRoot.sp.isp
        width: parent.width
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        text: [tabRoot.sp.server ? "Server " + tabRoot.sp.server : "", tabRoot.sp.isp ? "ISP " + tabRoot.sp.isp : ""].filter(x => x).join("  ·  ")
        font.pixelSize: Theme.fontSizeSmall - 2
        color: Theme.surfaceVariantText
    }

    // ── Start / cancel ──
    Column {
        width: parent.width
        spacing: Theme.spacingXS

        Chip {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 34
            icon: tabRoot.running ? "stop" : "speed"
            label: tabRoot.running ? "Cancel" : tabRoot.confirmMetered ? "Metered network: click again" : tabRoot.hasResult ? "Run again" : "Start test"
            selected: !tabRoot.running
            color: tabRoot.confirmMetered ? Theme.warning : (tabRoot.running ? Theme.withAlpha(Theme.surfaceVariantText, 0.15) : Theme.primary)
            onClicked: tabRoot.running ? tabRoot.host.requestSpeedTest("cancel") : tabRoot.start()
        }

        StyledText {
            width: parent.width
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            text: (tabRoot.metered ? "You're on a metered network. " : "") + "A test uses up to about " + tabRoot.host.fmtBytes(tabRoot.host.speedBudgetMb * 1e6 * 4 / 3) + " of data (speed.cloudflare.com)."
            font.pixelSize: Theme.fontSizeSmall - 2
            color: tabRoot.metered ? Theme.warning : Theme.surfaceVariantText
        }
    }

    // ── Recent results ──
    Column {
        visible: (tabRoot.sp.history || []).length > 0
        width: parent.width
        spacing: Theme.spacingXS

        StyledText {
            text: "Recent tests"
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Bold
            color: Theme.surfaceVariantText
        }

        Repeater {
            model: tabRoot.active ? (tabRoot.sp.history || []).slice(0, 5) : []
            delegate: Row {
                required property var modelData
                width: parent.width
                spacing: Theme.spacingS

                StyledText {
                    width: 78
                    text: tabRoot.ago(modelData.at)
                    font.pixelSize: Theme.fontSizeSmall - 1
                    color: Theme.surfaceVariantText
                }
                StyledText {
                    width: parent.width - 78 - resultRow.width - Theme.spacingS * 2
                    elide: Text.ElideRight
                    text: modelData.network || "Unknown network"
                    font.pixelSize: Theme.fontSizeSmall - 1
                    color: Theme.surfaceText
                }
                Row {
                    id: resultRow
                    spacing: 8
                    StyledText {
                        text: "↓ " + tabRoot.host.fmtMbps(modelData.down)
                        font.pixelSize: Theme.fontSizeSmall - 1
                        color: tabRoot.host.downColor
                    }
                    StyledText {
                        text: "↑ " + tabRoot.host.fmtMbps(modelData.up)
                        font.pixelSize: Theme.fontSizeSmall - 1
                        color: tabRoot.host.upColor
                    }
                    StyledText {
                        text: Math.round(modelData.ping) + " ms"
                        font.pixelSize: Theme.fontSizeSmall - 1
                        color: Theme.surfaceVariantText
                    }
                }
            }
        }
    }
}
