import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Widgets

Column {
    id: tabRoot

    property var host
    readonly property bool active: visible && host.tab === "apps"
    readonly property var usage: active ? host.appRows(host.appPeriod) : ({
            rows: [],
            unattributed: 0,
            consumption: 0
        })
    readonly property real max: host.maxOf(usage.rows)

    spacing: Theme.spacingM

    Row {
        spacing: Theme.spacingXS
        Repeater {
            model: [[1, "Today"], [7, "7 days"], [30, "30 days"]]
            delegate: Chip {
                required property var modelData
                label: modelData[1]
                selected: tabRoot.host.appPeriod === modelData[0]
                onClicked: tabRoot.host.appPeriod = modelData[0]
            }
        }
    }

    StyledText {
        visible: !tabRoot.host.trackApps
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Per-app tracking is turned off in the plugin settings."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }

    Flickable {
        id: appFlick
        visible: tabRoot.host.trackApps
        width: parent.width
        height: Math.min(contentHeight, 380)
        contentHeight: appCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: appCol
            width: appFlick.width
            spacing: Theme.spacingM

            StyledText {
                visible: tabRoot.usage.rows.length === 0
                text: "No app traffic recorded yet."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            Repeater {
                model: tabRoot.usage.rows
                delegate: Column {
                    id: appRow
                    required property var modelData
                    readonly property var entry: tabRoot.host.appEntry(modelData.name)
                    readonly property string iconSrc: entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : ""
                    width: appCol.width
                    spacing: 4

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        Item {
                            width: 26
                            height: 26
                            anchors.verticalCenter: parent.verticalCenter
                            IconImage {
                                anchors.fill: parent
                                visible: appRow.iconSrc !== ""
                                source: appRow.iconSrc
                                asynchronous: true
                            }
                            DankIcon {
                                anchors.centerIn: parent
                                visible: appRow.iconSrc === ""
                                name: appRow.modelData.name === "System" || /^[A-Z][a-zA-Z]+$/.test(appRow.modelData.name) && !appRow.entry ? "settings" : "apps"
                                size: 20
                                color: Theme.surfaceVariantText
                            }
                        }

                        StyledText {
                            width: parent.width - 26 - appRight.width - Theme.spacingS * 2
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: appRow.entry && appRow.entry.name ? appRow.entry.name : appRow.modelData.name
                            font.pixelSize: Theme.fontSizeSmall + 1
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        Column {
                            id: appRight
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            StyledText {
                                anchors.right: parent.right
                                text: tabRoot.host.fmtBytes(appRow.modelData.total)
                                font.pixelSize: Theme.fontSizeSmall + 1
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }
                            Row {
                                anchors.right: parent.right
                                spacing: 6
                                StyledText {
                                    text: "↓ " + tabRoot.host.fmtBytes(appRow.modelData.rx)
                                    font.pixelSize: Theme.fontSizeSmall - 2
                                    color: tabRoot.host.downColor
                                }
                                StyledText {
                                    text: "↑ " + tabRoot.host.fmtBytes(appRow.modelData.tx)
                                    font.pixelSize: Theme.fontSizeSmall - 2
                                    color: tabRoot.host.upColor
                                }
                            }
                        }
                    }

                    UsageBar {
                        width: parent.width
                        rx: appRow.modelData.rx
                        tx: appRow.modelData.tx
                        max: tabRoot.max
                        downColor: tabRoot.host.downColor
                        upColor: tabRoot.host.upColor
                    }
                }
            }

            // What TCP sampling could not see
            Row {
                visible: tabRoot.usage.unattributed > 0 && tabRoot.usage.rows.length > 0
                width: parent.width
                spacing: Theme.spacingS
                DankIcon {
                    name: "help"
                    size: 20
                    width: 26
                    color: Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    width: parent.width - 26 - unTotal.width - Theme.spacingS * 2
                    anchors.verticalCenter: parent.verticalCenter
                    StyledText {
                        text: "Not attributed"
                        font.pixelSize: Theme.fontSizeSmall + 1
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                    }
                    StyledText {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "UDP/QUIC (often video streaming and calls), very short connections and protocol overhead"
                        font.pixelSize: Theme.fontSizeSmall - 2
                        color: Theme.surfaceVariantText
                    }
                }
                StyledText {
                    id: unTotal
                    anchors.verticalCenter: parent.verticalCenter
                    text: tabRoot.host.fmtBytes(tabRoot.usage.unattributed)
                    font.pixelSize: Theme.fontSizeSmall + 1
                    font.weight: Font.Bold
                    color: Theme.surfaceVariantText
                }
            }
        }
    }
}
