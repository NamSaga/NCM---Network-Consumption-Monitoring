import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "dataUsage"

    StyledText {
        width: parent.width
        text: "Data Usage"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Tracks daily download and upload for every network you use: Wi-Fi, Ethernet, USB/Bluetooth tethering and mobile data. Traffic you share through your own hotspot is shown separately so it is never counted twice."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SelectionSetting {
        settingKey: "pillMode"
        label: "Bar shows"
        description: "What the DankBar pill displays"
        options: [
            { label: "Live speed (↓ ↑)", value: "speed" },
            { label: "Data used today", value: "today" },
            { label: "Both", value: "both" }
        ]
        defaultValue: "speed"
    }

    SliderSetting {
        settingKey: "updateInterval"
        label: "Update interval"
        description: "How often traffic counters are sampled"
        defaultValue: 2
        minimum: 1
        maximum: 10
        unit: "sec"
    }

    SelectionSetting {
        settingKey: "unitBase"
        label: "Size units"
        description: "Decimal (1 GB = 1000 MB) matches how carriers and ISPs bill. Binary (GiB) matches most Linux tools."
        options: [
            { label: "Decimal: KB, MB, GB", value: "decimal" },
            { label: "Binary: KiB, MiB, GiB", value: "binary" }
        ]
        defaultValue: "decimal"
    }

    SelectionSetting {
        settingKey: "speedUnit"
        label: "Speed units"
        description: "Bytes per second, or bits per second like speed tests use"
        options: [
            { label: "MB/s (bytes)", value: "bytes" },
            { label: "Mb/s (bits)", value: "bits" }
        ]
        defaultValue: "bytes"
    }

    SliderSetting {
        settingKey: "retentionDays"
        label: "Keep history for"
        description: "Older days are deleted automatically"
        defaultValue: 90
        minimum: 30
        maximum: 365
        unit: "days"
    }
}
