import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: tabRoot

    property var host
    readonly property bool active: visible && host.tab === "networks"

    spacing: Theme.spacingM

    Row {
        spacing: Theme.spacingXS
        Repeater {
            model: [[7, "7 days"], [30, "30 days"], [0, "All"]]
            delegate: Chip {
                required property var modelData
                label: modelData[1]
                selected: tabRoot.host.netPeriod === modelData[0]
                onClicked: tabRoot.host.netPeriod = modelData[0]
            }
        }
    }

    Flickable {
        id: netFlick
        width: parent.width
        height: Math.min(contentHeight, 360)
        contentHeight: netCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: netCol
            width: netFlick.width
            spacing: 2
            readonly property var rows: tabRoot.active ? tabRoot.host.networkRows(tabRoot.host.netPeriod) : []
            readonly property real max: tabRoot.host.maxOf(rows)

            StyledText {
                visible: netCol.rows.length === 0
                text: "No data for this period."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
            Repeater {
                model: netCol.rows
                delegate: NetworkCard {
                    required property var modelData
                    host: tabRoot.host
                    row: modelData
                    max: netCol.max
                    subtitle: {
                        let s = tabRoot.host.kindName(modelData.kind);
                        if (modelData.metered)
                            s += " · metered";
                        s += " · " + modelData.days + (modelData.days === 1 ? " day" : " days");
                        return s;
                    }
                }
            }
        }
    }
}
