import QtQuick
import QtQuick.Layouts

// Hidrolik pompa, "normal start/stop" mantığıyla: START ve STOP ayrı, yaylı
// butonlardır. Pompanın çalıştığını makine hatırlar (mühürleme); ekran yalnızca
// makinenin bildirdiği durumu ve basıncı gösterir.
Rectangle {
    id: card

    required property Machine machine

    readonly property bool running: card.machine.pumpState === Machine.PumpRunning
    readonly property bool starting: card.machine.pumpState === Machine.PumpStarting
    readonly property bool stopping: card.machine.pumpState === Machine.PumpStopping

    readonly property string stateText: {
        switch (card.machine.pumpState) {
        case Machine.PumpStarting:
            return qsTr("BAŞLIYOR…")
        case Machine.PumpRunning:
            return qsTr("ÇALIŞIYOR")
        case Machine.PumpStopping:
            return qsTr("DURUYOR…")
        default:
            return qsTr("DURDU")
        }
    }

    implicitWidth: 300
    implicitHeight: 104
    radius: Theme.radius
    color: Theme.field
    border.color: Theme.panelBorder

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: qsTr("POMPA")
                font.pixelSize: Theme.fontSmall
                font.bold: true
                color: Theme.textMuted
            }

            RowLayout {
                spacing: 8

                // Durum lambası: yeşil = çalışıyor, turuncu = basınç değişiyor, gri = durdu
                Rectangle {
                    implicitWidth: 12
                    implicitHeight: 12
                    radius: 6
                    color: card.running ? Theme.ok : card.starting || card.stopping ? Theme.active : Theme.idle
                }

                Text {
                    objectName: "pumpState"
                    text: card.stateText
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                    color: Theme.text
                }
            }

            Text {
                objectName: "pumpPressure"
                text: qsTr("Basınç: %1 bar").arg(card.machine.pressure.toFixed(0))
                font.pixelSize: Theme.fontSmall
                color: Theme.textMuted
            }
        }

        ColumnLayout {
            spacing: 6

            HmiButton {
                objectName: "pumpStart"
                implicitWidth: 96
                implicitHeight: 37
                text: qsTr("START")
                font.pixelSize: 15
                accent: Theme.ok
                enabled: !card.running && !card.starting
                onClicked: card.machine.startPump()
            }

            HmiButton {
                objectName: "pumpStop"
                implicitWidth: 96
                implicitHeight: 37
                text: qsTr("STOP")
                font.pixelSize: 15
                enabled: card.running || card.starting
                onClicked: card.machine.stopPump()
            }
        }
    }
}
