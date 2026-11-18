import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: chip

    property string label: ""
    property string icon: ""
    property bool selected: false
    signal clicked

    height: 28
    width: chipRow.implicitWidth + Theme.spacingM * 2
    radius: height / 2
    color: selected ? Theme.primary : Theme.withAlpha(Theme.surfaceVariantText, chipMouse.containsMouse ? 0.18 : 0.1)

    Row {
        id: chipRow
        anchors.centerIn: parent
        spacing: 4

        DankIcon {
            visible: chip.icon !== ""
            name: chip.icon
            size: 14
            color: chip.selected ? Theme.onPrimary : Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
        StyledText {
            visible: chip.label !== ""
            text: chip.label
            font.pixelSize: Theme.fontSizeSmall
            font.weight: chip.selected ? Font.Bold : Font.Normal
            color: chip.selected ? Theme.onPrimary : Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: chipMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
