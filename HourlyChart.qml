import QtQuick
import qs.Common
import qs.Widgets

// 24 stacked bars (download at the base, upload on top) for one day.
// Hovering a column shows that hour's numbers in the caption line.
Column {
    id: chart

    property var host
    property var hours: []           // [[rx, tx] × 24]
    property int currentHour: -1     // highlights the running hour (today only)
    property real plotHeight: 64

    property int hoverIndex: -1
    readonly property real maxTotal: {
        let m = 0;
        for (let i = 0; i < hours.length; i++)
            m = Math.max(m, (hours[i][0] || 0) + (hours[i][1] || 0));
        return m;
    }
    readonly property int peakHour: {
        let best = -1, m = 0;
        for (let i = 0; i < hours.length; i++) {
            const t = (hours[i][0] || 0) + (hours[i][1] || 0);
            if (t > m) {
                m = t;
                best = i;
            }
        }
        return best;
    }

    function pad(h) {
        return (h < 10 ? "0" : "") + h;
    }

    spacing: 4

    // Caption: hover readout, or peak hour summary
    Item {
        width: parent.width
        height: caption.implicitHeight

        StyledText {
            id: caption
            width: parent.width
            elide: Text.ElideRight
            font.pixelSize: Theme.fontSizeSmall - 2
            color: chart.hoverIndex >= 0 ? Theme.surfaceText : Theme.surfaceVariantText
            text: {
                const i = chart.hoverIndex;
                if (i >= 0) {
                    const e = chart.hours[i] || [0, 0];
                    return chart.pad(i) + ":00–" + chart.pad((i + 1) % 24) + ":00   ↓ " + chart.host.fmtBytes(e[0]) + "   ↑ " + chart.host.fmtBytes(e[1]);
                }
                if (chart.peakHour < 0)
                    return "By hour: no traffic yet";
                return "By hour · busiest " + chart.pad(chart.peakHour) + ":00 (" + chart.host.fmtBytes(chart.maxTotal) + ")";
            }
        }
    }

    Item {
        id: plot
        width: parent.width
        height: chart.plotHeight

        readonly property real gap: 2
        readonly property real barW: Math.max(2, (width - gap * 23) / 24)

        // baseline
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.withAlpha(Theme.surfaceVariantText, 0.25)
        }

        Repeater {
            model: 24
            delegate: Item {
                id: col
                required property int index
                readonly property var e: chart.hours[index] || [0, 0]
                readonly property real rx: e[0] || 0
                readonly property real tx: e[1] || 0
                readonly property real scale: chart.maxTotal > 0 ? (plot.height - 3) / chart.maxTotal : 0
                readonly property real rxH: rx > 0 ? Math.max(2, rx * scale) : 0
                readonly property real txH: tx > 0 ? Math.max(2, tx * scale) : 0
                readonly property bool dim: chart.hoverIndex >= 0 && chart.hoverIndex !== index

                x: index * (plot.barW + plot.gap)
                width: plot.barW
                height: plot.height

                // hover track (full-height hit target)
                Rectangle {
                    anchors.fill: parent
                    radius: 3
                    color: Theme.withAlpha(Theme.surfaceVariantText, chart.hoverIndex === col.index ? 0.12 : (col.index === chart.currentHour ? 0.06 : 0))
                }

                // download segment, anchored to the baseline
                Rectangle {
                    visible: col.rxH > 0
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    width: parent.width
                    height: col.rxH
                    radius: Math.min(2, width / 2)
                    color: chart.host.downColor
                    opacity: col.dim ? 0.45 : 1
                }

                // upload segment, stacked with a 2px gap
                Rectangle {
                    visible: col.txH > 0
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1 + col.rxH + (col.rxH > 0 ? 2 : 0)
                    width: parent.width
                    height: col.txH
                    radius: Math.min(2, width / 2)
                    color: chart.host.upColor
                    opacity: col.dim ? 0.45 : 1
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: chart.hoverIndex = col.index
                    onExited: if (chart.hoverIndex === col.index)
                        chart.hoverIndex = -1
                }
            }
        }
    }

    // x-axis labels
    Item {
        width: parent.width
        height: 12
        Repeater {
            model: [0, 6, 12, 18]
            delegate: StyledText {
                required property int modelData
                x: modelData * (plot.barW + plot.gap)
                text: chart.pad(modelData)
                font.pixelSize: Theme.fontSizeSmall - 3
                color: Theme.surfaceVariantText
            }
        }
        StyledText {
            anchors.right: parent.right
            text: "24"
            font.pixelSize: Theme.fontSizeSmall - 3
            color: Theme.surfaceVariantText
        }
    }
}
