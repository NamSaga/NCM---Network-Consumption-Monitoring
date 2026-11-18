import QtQuick
import qs.Common
import qs.Widgets

// Network row for the Networks tab. Click to open an editor (rename).
Rectangle {
    id: card

    property var host
    property var row: ({})
    property real max: 1
    property string subtitle: ""

    readonly property bool open: host.editingKey === row.key
    readonly property string origLabel: row.origLabel || row.label || ""

    width: parent ? parent.width : 0
    height: cardCol.implicitHeight + Theme.spacingS * 2
    radius: Theme.cornerRadius / 2
    color: open || hover.containsMouse ? Theme.withAlpha(Theme.surfaceVariantText, 0.08) : "transparent"

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.host.editingKey = card.open ? "" : card.row.key
    }

    Column {
        id: cardCol
        x: Theme.spacingS
        y: Theme.spacingS
        width: parent.width - Theme.spacingS * 2
        spacing: Theme.spacingS

        NetLine {
            host: card.host
            row: card.row
            max: card.max
            subtitle: card.subtitle
        }

        // ── Editor ──
        Column {
            id: editor
            visible: card.open
            width: parent.width
            spacing: Theme.spacingS

            StyledText {
                text: "Name"
                font.pixelSize: Theme.fontSizeSmall - 1
                font.weight: Font.Bold
                color: Theme.surfaceVariantText
            }

            Row {
                width: parent.width
                spacing: Theme.spacingS

                DankTextField {
                    id: nameField
                    width: parent.width - saveName.width - Theme.spacingS
                    height: 34
                    placeholderText: card.origLabel
                    text: card.row.origLabel ? card.row.label : ""
                    onAccepted: card.host.setAlias(card.row.key, text)
                }
                Chip {
                    id: saveName
                    anchors.verticalCenter: parent.verticalCenter
                    label: "Save"
                    selected: true
                    onClicked: card.host.setAlias(card.row.key, nameField.text)
                }
            }

            StyledText {
                visible: !!card.row.origLabel
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Detected as \"" + card.origLabel + "\". Clear the field and save to use that name again."
                font.pixelSize: Theme.fontSizeSmall - 2
                color: Theme.surfaceVariantText
            }
        }
    }
}
