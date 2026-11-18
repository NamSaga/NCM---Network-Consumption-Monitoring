import QtQuick
import qs.Common
import qs.Widgets

// Network row for the Networks tab. Click to open an editor (rename, data cap).
Rectangle {
    id: card

    property var host
    property var row: ({})
    property real max: 1
    property string subtitle: ""

    readonly property bool open: host.editingKey === row.key
    readonly property bool isAll: row.key === "__all__"
    readonly property string origLabel: row.origLabel || row.label || ""
    readonly property var capStatus: host.capStatus(row.key)

    // editor state, refreshed whenever the editor opens
    property string capPeriod: "month"
    property bool capInGb: true

    function loadEditor() {
        const cap = host.caps[row.key];
        capPeriod = cap ? cap.period || "month" : "month";
        const gb = host.decimalUnits ? 1e9 : 1073741824;
        const mb = host.decimalUnits ? 1e6 : 1048576;
        if (cap) {
            capInGb = cap.limit >= gb;
            capField.text = String(+(cap.limit / (capInGb ? gb : mb)).toFixed(2));
            dayField.text = String(cap.resetDay || 1);
        } else {
            capInGb = true;
            capField.text = "";
            dayField.text = "1";
        }
        nameField.text = row.origLabel ? row.label : "";
    }

    function saveCap() {
        const n = parseFloat(capField.text.replace(",", "."));
        if (!(n > 0))
            return;
        const unit = capInGb ? (host.decimalUnits ? 1e9 : 1073741824) : (host.decimalUnits ? 1e6 : 1048576);
        const day = Math.max(1, Math.min(31, parseInt(dayField.text) || 1));
        host.setCap(row.key, {
            limit: Math.round(n * unit),
            period: capPeriod,
            resetDay: day
        });
    }

    onOpenChanged: if (open)
        loadEditor()

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

        CapBar {
            width: parent.width
            host: card.host
            status: card.capStatus
        }

        // ── Editor ──
        Column {
            id: editor
            visible: card.open
            width: parent.width
            spacing: Theme.spacingS
            topPadding: Theme.spacingXS

            // Name
            StyledText {
                visible: !card.isAll
                text: "Name"
                font.pixelSize: Theme.fontSizeSmall - 1
                font.weight: Font.Bold
                color: Theme.surfaceVariantText
            }

            Row {
                visible: !card.isAll
                width: parent.width
                spacing: Theme.spacingS

                DankTextField {
                    id: nameField
                    width: parent.width - saveName.width - Theme.spacingS
                    height: 34
                    placeholderText: card.origLabel
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
                visible: !card.isAll && !!card.row.origLabel
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Detected as \"" + card.origLabel + "\". Clear the field and save to use that name again."
                font.pixelSize: Theme.fontSizeSmall - 2
                color: Theme.surfaceVariantText
            }

            // Data cap
            StyledText {
                text: "Data cap"
                font.pixelSize: Theme.fontSizeSmall - 1
                font.weight: Font.Bold
                color: Theme.surfaceVariantText
            }

            Row {
                spacing: Theme.spacingXS
                Repeater {
                    model: [["day", "Daily"], ["week", "Weekly"], ["month", "Monthly"]]
                    delegate: Chip {
                        required property var modelData
                        label: modelData[1]
                        selected: card.capPeriod === modelData[0]
                        onClicked: card.capPeriod = modelData[0]
                    }
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingS

                DankTextField {
                    id: capField
                    width: 90
                    height: 34
                    placeholderText: "Amount"
                    onAccepted: card.saveCap()
                }
                Chip {
                    anchors.verticalCenter: parent.verticalCenter
                    label: card.host.decimalUnits ? "MB" : "MiB"
                    selected: !card.capInGb
                    onClicked: card.capInGb = false
                }
                Chip {
                    anchors.verticalCenter: parent.verticalCenter
                    label: card.host.decimalUnits ? "GB" : "GiB"
                    selected: card.capInGb
                    onClicked: card.capInGb = true
                }
                StyledText {
                    visible: card.capPeriod === "month"
                    anchors.verticalCenter: parent.verticalCenter
                    text: "resets on day"
                    font.pixelSize: Theme.fontSizeSmall - 1
                    color: Theme.surfaceVariantText
                }
                DankTextField {
                    id: dayField
                    visible: card.capPeriod === "month"
                    width: 48
                    height: 34
                    placeholderText: "1"
                    onAccepted: card.saveCap()
                }
            }

            Row {
                spacing: Theme.spacingXS
                Chip {
                    label: card.capStatus ? "Update cap" : "Set cap"
                    icon: "check"
                    selected: true
                    onClicked: card.saveCap()
                }
                Chip {
                    visible: !!card.capStatus
                    label: "Remove cap"
                    icon: "delete"
                    onClicked: card.host.setCap(card.row.key, null)
                }
            }

            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                text: card.isAll ? "Counts every network except traffic shared through your own hotspot. You get a notification at 80% and 100%." : "You get a notification at 80% and 100% of the cap."
                font.pixelSize: Theme.fontSizeSmall - 2
                color: Theme.surfaceVariantText
            }
        }
    }
}
