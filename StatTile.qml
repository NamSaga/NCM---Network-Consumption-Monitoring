import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: st

    property string title: ""
    property string value: ""
    property color valueColor: Theme.surfaceText

    height: 52
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceVariantText, 0.08)

    Column {
        anchors.centerIn: parent
        spacing: 1
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: st.value
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Bold
            color: st.valueColor
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: st.title
            font.pixelSize: Theme.fontSizeSmall - 2
            color: Theme.surfaceVariantText
        }
    }
}
