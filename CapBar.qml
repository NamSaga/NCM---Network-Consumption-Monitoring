import QtQuick
import qs.Common
import qs.Widgets

// Progress against a data cap for the current billing cycle.
Column {
    id: cb

    property var host
    property var status: null       // from host.capStatus()
    property bool showLabel: false

    readonly property color tone: !status ? Theme.primary : status.level >= 100 ? Theme.error : status.level >= 80 ? Theme.warning : Theme.primary

    visible: !!status
    spacing: 3

    Row {
        width: parent.width
        spacing: Theme.spacingS

        DankIcon {
            visible: !!cb.status && cb.status.level > 0
            name: cb.status && cb.status.level >= 100 ? "error" : "warning"
            size: 14
            color: cb.tone
            anchors.verticalCenter: parent.verticalCenter
        }
        StyledText {
            id: capTitle
            width: parent.width - capAmount.width - Theme.spacingS * 2 - (cb.status && cb.status.level > 0 ? 14 : 0)
            elide: Text.ElideRight
            text: cb.status ? (cb.showLabel ? cb.status.label + " · " : "") + cb.host.periodName(cb.status.cap.period).toLowerCase() + " cap" : ""
            font.pixelSize: Theme.fontSizeSmall - 1
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
        StyledText {
            id: capAmount
            text: cb.status ? cb.host.fmtBytes(cb.status.used) + " of " + cb.host.fmtBytes(cb.status.cap.limit) : ""
            font.pixelSize: Theme.fontSizeSmall - 1
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Item {
        width: parent.width
        height: 6
        Rectangle {
            anchors.fill: parent
            radius: 3
            color: Theme.withAlpha(Theme.surfaceVariantText, 0.12)
        }
        Rectangle {
            height: parent.height
            width: cb.status ? Math.max(cb.status.used > 0 ? 3 : 0, parent.width * Math.min(1, cb.status.pct)) : 0
            radius: 3
            color: cb.tone
        }
    }

    StyledText {
        width: parent.width
        elide: Text.ElideRight
        text: {
            const s = cb.status;
            if (!s)
                return "";
            const resets = s.cap.period === "day" ? "resets at midnight" : "resets " + Qt.formatDate(s.endDate, "d MMM") + " (" + s.daysLeft + (s.daysLeft === 1 ? " day)" : " days)");
            if (s.level >= 100)
                return "Over by " + cb.host.fmtBytes(s.used - s.cap.limit) + " · " + resets;
            return Math.floor(s.pct * 100) + "% used · " + cb.host.fmtBytes(s.cap.limit - s.used) + " left · " + resets;
        }
        font.pixelSize: Theme.fontSizeSmall - 2
        color: cb.status && cb.status.level > 0 ? cb.tone : Theme.surfaceVariantText
    }
}
