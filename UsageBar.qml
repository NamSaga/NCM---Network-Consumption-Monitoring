import QtQuick
import qs.Common

// Two-tone bar: download segment then upload segment, scaled to `max`.
Item {
    id: ub

    property real rx: 0
    property real tx: 0
    property real max: 1
    property real barOpacity: 1
    property color downColor: Theme.primary
    property color upColor: Theme.error

    readonly property real full: width * Math.min(1, (rx + tx) / Math.max(1, max))
    readonly property real rxWidth: full * (rx / Math.max(1, rx + tx))

    height: 6

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.withAlpha(Theme.surfaceVariantText, 0.12)
    }
    Rectangle {
        visible: ub.tx > 0
        height: parent.height
        width: ub.full
        radius: height / 2
        opacity: ub.barOpacity
        color: ub.upColor
    }
    Rectangle {
        visible: ub.rx > 0
        height: parent.height
        width: Math.max(ub.rxWidth, ub.tx > 0 ? 0 : 2)
        radius: height / 2
        opacity: ub.barOpacity
        color: ub.downColor
    }
}
