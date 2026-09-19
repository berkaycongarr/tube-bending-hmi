import QtQuick
import QtQuick.Layouts

// Ana ekran: üstte durum ve eksen konumları, ortada referans arama,
// altta çalışma modu ve saat.
Window {
    id: root

    // main.cpp tarafından verilen makine nesnesi (demoda SimMachine).
    required property Machine machine

    width: 1280
    height: 760
    minimumWidth: 1024
    minimumHeight: 600
    visible: true
    title: qsTr("Boru Bükme Makinesi")
    color: Theme.background

    // Şu an referans arayan eksen (yoksa null).
    readonly property Axis homingAxis: machine.axisB.homing ? machine.axisB
                                     : machine.axisA.homing ? machine.axisA
                                     : machine.axisX.homing ? machine.axisX
                                     : null

    readonly property string stateText: {
        switch (machine.state) {
        case Machine.Homing:
            return qsTr("REFERANS ARANIYOR")
        case Machine.Ready:
            return qsTr("HAZIR")
        default:
            return qsTr("REFERANSSIZ")
        }
    }

    readonly property string stateHint: {
        switch (machine.state) {
        case Machine.Homing:
            return homingAxis ? qsTr("%1 ekseni referans noktasına gidiyor").arg(homingAxis.name) : ""
        case Machine.Ready:
            return qsTr("Tüm eksenler referanslı")
        default:
            return qsTr("Üretimden önce referans aranmalı")
        }
    }

    readonly property color stateColor: {
        switch (machine.state) {
        case Machine.Homing:
            return Theme.active
        case Machine.Ready:
            return Theme.ok
        default:
            return Theme.idle
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // Üst şerit: durum, eksen konumları, STOP
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap

            Rectangle {
                Layout.fillWidth: true
                Layout.minimumWidth: 240
                Layout.preferredHeight: 72
                radius: Theme.radius
                color: Theme.panel
                border.color: Theme.panelBorder

                // Soldaki renkli şerit makinenin durumunu gösterir.
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 8
                    radius: Theme.radius
                    color: root.stateColor
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 24
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: root.stateText
                        font.pixelSize: Theme.fontTitle
                        font.bold: true
                        color: Theme.text
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: root.stateHint
                        font.pixelSize: Theme.fontSmall
                        color: Theme.textMuted
                        elide: Text.ElideRight
                    }
                }
            }

            AxisDisplay {
                Layout.minimumWidth: 170
                axis: root.machine.axisX
                title: qsTr("İlerletme")
            }

            AxisDisplay {
                Layout.minimumWidth: 170
                axis: root.machine.axisB
                title: qsTr("Büküm")
            }

            AxisDisplay {
                Layout.minimumWidth: 170
                axis: root.machine.axisA
                title: qsTr("Rotasyon")
            }

            HmiButton {
                objectName: "stopButton"
                Layout.preferredWidth: 140
                Layout.preferredHeight: 72
                text: qsTr("STOP")
                accent: Theme.danger
                filled: true
                onClicked: root.machine.stop()
            }
        }

        // Orta alan: referans arama
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radius
            color: Theme.panel
            border.color: Theme.panelBorder

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - 64, 620)
                spacing: 14

                Text {
                    text: qsTr("Referans Arama")
                    font.pixelSize: Theme.fontLarge
                    font.bold: true
                    color: Theme.text
                }

                Text {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 6
                    text: qsTr("Eksenler sırayla referans noktasına gider ve orada sıfırlanır.")
                    font.pixelSize: Theme.fontNormal
                    color: Theme.textMuted
                    wrapMode: Text.WordWrap
                }

                HomingStep {
                    Layout.fillWidth: true
                    order: 1
                    axis: root.machine.axisB
                    title: qsTr("Büküm kolu geri çekilir")
                }

                HomingStep {
                    Layout.fillWidth: true
                    order: 2
                    axis: root.machine.axisA
                    title: qsTr("Boru rotasyonu sıfırlanır")
                }

                HomingStep {
                    Layout.fillWidth: true
                    order: 3
                    axis: root.machine.axisX
                    title: qsTr("İlerletme arabası referansa gider")
                }

                HmiButton {
                    objectName: "homeButton"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 10
                    Layout.preferredWidth: 360
                    Layout.preferredHeight: 80
                    text: root.machine.state === Machine.Ready ? qsTr("TEKRAR REFERANS ARA")
                                                               : qsTr("REFERANS ARA (HOME)")
                    enabled: root.machine.state !== Machine.Homing
                    onClicked: root.machine.startHoming()
                }
            }
        }

        // Alt şerit: çalışma modu ve saat
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap

            Rectangle {
                visible: root.machine.simulation
                implicitWidth: simText.implicitWidth + 28
                implicitHeight: 30
                radius: 15
                color: "transparent"
                border.color: Theme.active
                border.width: 2

                Text {
                    id: simText

                    anchors.centerIn: parent
                    text: qsTr("SİMÜLASYON · gerçek makineye bağlı değil")
                    font.pixelSize: Theme.fontSmall
                    font.bold: true
                    color: Theme.text
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                id: clock

                font.pixelSize: Theme.fontSmall
                color: Theme.textMuted
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: clock.text = Qt.formatDateTime(new Date(), "dd.MM.yyyy  HH:mm:ss")
    }

    // Referans arama adımlarından biri: sıra numarası, eksen, açıklama, durum.
    component HomingStep: Rectangle {
        id: step

        required property int order
        required property Axis axis
        required property string title

        implicitHeight: 52
        radius: Theme.radius
        color: step.axis.homing ? "#1ac77800" : "transparent"
        border.color: step.axis.homing ? Theme.active : Theme.panelBorder

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 16
            spacing: 14

            Rectangle {
                implicitWidth: 30
                implicitHeight: 30
                radius: 15
                color: step.axis.homed ? Theme.ok : step.axis.homing ? Theme.active : Theme.idle

                Text {
                    anchors.centerIn: parent
                    text: step.axis.homed ? "✓" : step.order.toString()
                    font.pixelSize: Theme.fontSmall
                    font.bold: true
                    color: "white"
                }
            }

            Text {
                text: step.axis.name
                font.pixelSize: 18
                font.bold: true
                color: Theme.text
            }

            Text {
                Layout.fillWidth: true
                text: step.title
                font.pixelSize: Theme.fontNormal
                color: Theme.text
                elide: Text.ElideRight
            }

            Text {
                text: step.axis.homed ? qsTr("Tamam")
                                      : step.axis.homing ? qsTr("Aranıyor…") : qsTr("Bekliyor")
                font.pixelSize: Theme.fontNormal
                font.bold: step.axis.homing
                color: step.axis.homed ? Theme.ok : Theme.textMuted
            }
        }
    }
}
