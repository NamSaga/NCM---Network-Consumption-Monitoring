import QtQuick
import qs.Common
import qs.Widgets

// A network line: icon, name/subtitle, total + ↓/↑, bar.
Item {
    id: nl

    property var host
    property var row: ({})
    property real max: 1
    property bool compact: false
    property string subtitle: ""   // overrides the default subtitle when set

    readonly property bool isShared: row.kind === "sharing"
    readonly property int iconBox: compact ? 22 : 30

    width: parent ? parent.width : 0
    height: nlCol.implicitHeight

    Column {
        id: nlCol
        width: parent.width
        spacing: 4

        Row {
            width: parent.width
            spacing: Theme.spacingS

            Rectangle {
                width: nl.iconBox
                height: width
                radius: width / 2
                color: Theme.withAlpha(nl.isShared ? Theme.surfaceVariantText : Theme.primary, 0.14)
                anchors.verticalCenter: parent.verticalCenter
                DankIcon {
                    anchors.centerIn: parent
                    name: nl.host.kindIcon(nl.row.kind)
                    size: nl.compact ? 14 : 18
                    color: nl.isShared ? Theme.surfaceVariantText : Theme.primary
                }
            }

            Column {
                width: parent.width - nl.iconBox - rightCol.width - Theme.spacingS * 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                StyledText {
                    width: parent.width
                    text: nl.row.label || ""
                    elide: Text.ElideRight
                    font.pixelSize: Theme.fontSizeSmall + (nl.compact ? 0 : 1)
                    font.weight: Font.Medium
                    color: nl.isShared ? Theme.surfaceVariantText : Theme.surfaceText
                }
                StyledText {
                    visible: !nl.compact
                    width: parent.width
                    elide: Text.ElideRight
                    text: {
                        if (nl.subtitle)
                            return nl.subtitle;
                        let s = nl.host.kindName(nl.row.kind);
                        if (nl.row.metered)
                            s += " · metered";
                        return s;
                    }
                    font.pixelSize: Theme.fontSizeSmall - 2
                    color: nl.row.metered ? Theme.warning : Theme.surfaceVariantText
                }
            }

            Column {
                id: rightCol
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                StyledText {
                    anchors.right: parent.right
                    text: nl.host.fmtBytes(nl.row.total)
                    font.pixelSize: Theme.fontSizeSmall + (nl.compact ? 0 : 1)
                    font.weight: Font.Bold
                    color: nl.isShared ? Theme.surfaceVariantText : Theme.surfaceText
                }
                Row {
                    anchors.right: parent.right
                    spacing: 6
                    StyledText {
                        text: "↓ " + nl.host.fmtBytes(nl.row.rx)
                        font.pixelSize: Theme.fontSizeSmall - 2
                        color: nl.host.downColor
                    }
                    StyledText {
                        text: "↑ " + nl.host.fmtBytes(nl.row.tx)
                        font.pixelSize: Theme.fontSizeSmall - 2
                        color: nl.host.upColor
                    }
                }
            }
        }

        UsageBar {
            visible: !nl.compact
            width: parent.width
            rx: nl.row.rx || 0
            tx: nl.row.tx || 0
            max: nl.max
            barOpacity: nl.isShared ? 0.45 : 1
            downColor: nl.host.downColor
            upColor: nl.host.upColor
        }
    }
}
