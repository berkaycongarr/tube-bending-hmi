import QtQuick
import QtQuick.Layouts

// Hareket sayfası: eksenleri elle sürme (jog).
Rectangle {
    id: page

    required property Machine machine

    // Seçili jog hızı. Güvenli olan yavaş hızla başlar.
    property bool fast: false

    radius: Theme.radius
    color: Theme.panel
    border.color: Theme.panelBorder

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        // Başlık ve jog hızı seçimi
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            spacing: Theme.gap

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: qsTr("Elle Sürme (Jog)")
                    font.pixelSize: Theme.fontLarge
                    font.bold: true
                    color: Theme.text
                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Butonu basılı tuttuğunuz sürece eksen hareket eder, bıraktığınızda durur.")
                    font.pixelSize: Theme.fontNormal
                    color: Theme.textMuted
                    wrapMode: Text.WordWrap
                }
            }

            Text {
                text: qsTr("Jog hızı")
                font.pixelSize: Theme.fontNormal
                color: Theme.textMuted
            }

            HmiButton {
                objectName: "speedSlow"
                implicitWidth: 120
                implicitHeight: 56
                text: qsTr("YAVAŞ")
                filled: !page.fast
                onClicked: page.fast = false
            }

            HmiButton {
                objectName: "speedFast"
                implicitWidth: 120
                implicitHeight: 56
                text: qsTr("HIZLI")
                filled: page.fast
                onClicked: page.fast = true
            }
        }

        JogRow {
            Layout.fillWidth: true
            machine: page.machine
            axis: page.machine.axisX
            title: qsTr("İlerletme")
            fast: page.fast
        }

        JogRow {
            Layout.fillWidth: true
            machine: page.machine
            axis: page.machine.axisB
            title: qsTr("Büküm")
            fast: page.fast
        }

        JogRow {
            Layout.fillWidth: true
            machine: page.machine
            axis: page.machine.axisA
            title: qsTr("Rotasyon")
            fast: page.fast
        }

        Item {
            Layout.fillHeight: true
        }
    }

    // Bir eksenin satırı: ad, konum, limit bilgisi ve − / + butonları.
    component JogRow: Rectangle {
        id: row

        required property Machine machine
        required property Axis axis
        required property string title
        property bool fast: false

        function formatValue(value: real): string {
            return value.toFixed(2) + (row.axis.rotary ? "°" : " mm")
        }

        readonly property string hint: {
            if (!row.axis.homed)
                return qsTr("Referanssız: yalnızca yavaş hız, limitler devre dışı")
            if (row.axis.atMinLimit)
                return qsTr("Alt limitte: %1").arg(row.formatValue(row.axis.minPosition))
            if (row.axis.atMaxLimit)
                return qsTr("Üst limitte: %1").arg(row.formatValue(row.axis.maxPosition))
            return qsTr("Limitler: %1 … %2").arg(row.formatValue(row.axis.minPosition))
                                            .arg(row.formatValue(row.axis.maxPosition))
        }

        implicitHeight: 88
        radius: Theme.radius
        color: "transparent"
        border.color: row.axis.moving ? Theme.active : Theme.panelBorder
        border.width: row.axis.moving ? 2 : 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 12
            spacing: 16

            ColumnLayout {
                Layout.preferredWidth: 130
                spacing: 0

                Text {
                    text: row.axis.name
                    font.pixelSize: 30
                    font.bold: true
                    color: Theme.text
                }

                Text {
                    text: row.title
                    font.pixelSize: Theme.fontNormal
                    color: Theme.textMuted
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: row.formatValue(row.axis.position)
                    font.pixelSize: 30
                    font.bold: true
                    color: Theme.text
                }

                Text {
                    Layout.fillWidth: true
                    text: row.hint
                    font.pixelSize: Theme.fontSmall
                    color: row.axis.homed ? Theme.textMuted : Theme.activeText
                    elide: Text.ElideRight
                }
            }

            JogButton {
                objectName: "jog" + row.axis.name + "Minus"
                Layout.preferredWidth: 100
                Layout.preferredHeight: 68
                machine: row.machine
                axis: row.axis
                direction: -1
                fast: row.fast
            }

            JogButton {
                objectName: "jog" + row.axis.name + "Plus"
                Layout.preferredWidth: 100
                Layout.preferredHeight: 68
                machine: row.machine
                axis: row.axis
                direction: 1
                fast: row.fast
            }
        }
    }
}
