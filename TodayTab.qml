import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: tabRoot

    property var host
    readonly property bool active: visible && host.tab === "today"

    spacing: Theme.spacingM

    Rectangle {
        width: parent.width
        height: 64
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceVariantText, 0.08)

        Column {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            StyledText {
                text: "Used today"
                font.pixelSize: Theme.fontSizeSmall - 1
                color: Theme.surfaceVariantText
            }
            StyledText {
                text: tabRoot.host.fmtBytes(tabRoot.host.todayTotal)
                font.pixelSize: Theme.fontSizeLarge + 2
                font.weight: Font.Bold
                color: Theme.surfaceText
            }
        }
        Column {
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            StyledText {
                anchors.right: parent.right
                text: "↓ " + tabRoot.host.fmtBytes(tabRoot.host.todayTotals.rx)
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: tabRoot.host.downColor
            }
            StyledText {
                anchors.right: parent.right
                text: "↑ " + tabRoot.host.fmtBytes(tabRoot.host.todayTotals.tx)
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: tabRoot.host.upColor
            }
        }
    }

    HourlyChart {
        width: parent.width
        host: tabRoot.host
        hours: tabRoot.active ? (tabRoot.host.live.hours || []) : []
        currentHour: new Date().getHours()
    }

    StyledText {
        text: "By network"
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Bold
        color: Theme.surfaceVariantText
    }

    Column {
        id: todayList
        width: parent.width
        spacing: Theme.spacingM
        readonly property var rows: tabRoot.active ? tabRoot.host.dayRows(tabRoot.host.live.today || {}) : []
        readonly property real max: tabRoot.host.maxOf(rows)

        StyledText {
            visible: todayList.rows.length === 0
            text: "No traffic recorded yet today."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
        Repeater {
            model: todayList.rows
            delegate: NetLine {
                required property var modelData
                host: tabRoot.host
                row: modelData
                max: todayList.max
            }
        }
    }

    StyledText {
        visible: tabRoot.host.todayTotals.sharedRx + tabRoot.host.todayTotals.sharedTx > 0
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Hotspot traffic is what your devices pulled through this machine. It already counts toward your uplink, so it is not added to the total again."
        font.pixelSize: Theme.fontSizeSmall - 2
        color: Theme.surfaceVariantText
    }
}
