import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: tabRoot

    property var host
    readonly property bool active: visible && host.tab === "history"
    readonly property var totals: active ? host.periodTotals() : ({
            week: 0,
            days30: 0,
            month: 0
        })

    spacing: Theme.spacingS

    Row {
        width: parent.width
        spacing: Theme.spacingS
        StatTile {
            width: (parent.width - Theme.spacingS * 2) / 3
            title: "Last 7 days"
            value: tabRoot.host.fmtBytes(tabRoot.totals.week)
        }
        StatTile {
            width: (parent.width - Theme.spacingS * 2) / 3
            title: "Last 30 days"
            value: tabRoot.host.fmtBytes(tabRoot.totals.days30)
        }
        StatTile {
            width: (parent.width - Theme.spacingS * 2) / 3
            title: Qt.formatDate(new Date(), "MMMM")
            value: tabRoot.host.fmtBytes(tabRoot.totals.month)
        }
    }

    Flickable {
        id: histFlick
        width: parent.width
        height: Math.min(contentHeight, 330)
        contentHeight: histCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: histCol
            width: histFlick.width
            spacing: 2
            readonly property var rows: tabRoot.active ? tabRoot.host.historyRows() : []
            readonly property real max: tabRoot.host.maxOf(rows)

            Repeater {
                model: histCol.rows
                delegate: Rectangle {
                    id: dayRow
                    required property var modelData
                    readonly property bool open: tabRoot.host.expandedDay === modelData.date
                    readonly property bool isToday: modelData.date === tabRoot.host.live.day
                    width: histCol.width
                    height: dayCol.implicitHeight + Theme.spacingS * 2
                    radius: Theme.cornerRadius / 2
                    color: open || dayMouse.containsMouse ? Theme.withAlpha(Theme.surfaceVariantText, 0.1) : "transparent"

                    MouseArea {
                        id: dayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tabRoot.host.expandedDay = dayRow.open ? "" : dayRow.modelData.date
                    }

                    Column {
                        id: dayCol
                        x: Theme.spacingS
                        y: Theme.spacingS
                        width: parent.width - Theme.spacingS * 2
                        spacing: Theme.spacingS

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS
                            StyledText {
                                id: dLabel
                                width: 92
                                text: tabRoot.host.dayLabel(dayRow.modelData.date)
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: dayRow.isToday ? Font.Bold : Font.Normal
                                color: dayRow.isToday ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            UsageBar {
                                width: parent.width - dLabel.width - dTotal.width - Theme.spacingS * 2
                                anchors.verticalCenter: parent.verticalCenter
                                rx: dayRow.modelData.rx
                                tx: dayRow.modelData.tx
                                max: histCol.max
                                downColor: tabRoot.host.downColor
                                upColor: tabRoot.host.upColor
                            }
                            StyledText {
                                id: dTotal
                                width: 70
                                horizontalAlignment: Text.AlignRight
                                text: tabRoot.host.fmtBytes(dayRow.modelData.total)
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Expanded: ↓/↑ split and per-network breakdown
                        Column {
                            visible: dayRow.open
                            width: parent.width
                            spacing: Theme.spacingS
                            Row {
                                spacing: Theme.spacingM
                                StyledText {
                                    text: "↓ " + tabRoot.host.fmtBytes(dayRow.modelData.rx)
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: tabRoot.host.downColor
                                }
                                StyledText {
                                    text: "↑ " + tabRoot.host.fmtBytes(dayRow.modelData.tx)
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: tabRoot.host.upColor
                                }
                            }
                            Repeater {
                                model: dayRow.open ? dayRow.modelData.nets : []
                                delegate: NetLine {
                                    required property var modelData
                                    host: tabRoot.host
                                    row: modelData
                                    compact: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
