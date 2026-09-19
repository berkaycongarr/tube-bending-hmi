import QtQuick
import QtQuick.Layouts

// Üretim sayfası. Şimdilik referans arama paneli var;
// ileride program tablosu da bu sayfaya gelecek.
Rectangle {
    id: page

    required property Machine machine

    // Mengene boruyu tutuyorsa X ve A kilitlidir; referans arama da kilitlenir.
    readonly property bool clampLocked: page.machine.axisX.interlock !== Axis.NoInterlock
                                        || page.machine.axisA.interlock !== Axis.NoInterlock

    radius: Theme.radius
    color: Theme.panel
    border.color: Theme.panelBorder

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 64, 680)
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
            text: qsTr("Eksenler sırayla referans noktasına gider. Orada eksene bilinen bir "
                       + "değer yazılır ve gerçek konumu belirlenmiş olur.")
            font.pixelSize: Theme.fontNormal
            color: Theme.textMuted
            wrapMode: Text.WordWrap
        }

        HomingStep {
            Layout.fillWidth: true
            order: 1
            axis: page.machine.axisB
            title: qsTr("Büküm kolu geri çekilir")
        }

        HomingStep {
            Layout.fillWidth: true
            order: 2
            axis: page.machine.axisA
            title: qsTr("Boru rotasyonu sıfırlanır")
        }

        HomingStep {
            Layout.fillWidth: true
            order: 3
            axis: page.machine.axisX
            title: qsTr("İlerletme arabası referansa gider")
        }

        HmiButton {
            objectName: "homeButton"
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            Layout.preferredWidth: 360
            Layout.preferredHeight: 80
            text: page.machine.state === Machine.Ready ? qsTr("TEKRAR REFERANS ARA")
                                                       : qsTr("REFERANS ARA (HOME)")
            enabled: page.machine.state !== Machine.Homing && !page.clampLocked
            onClicked: page.machine.startHoming()
        }

        // Referans aramada X ve A hareket eder; mengene boruyu tutuyorsa aranamaz.
        Text {
            objectName: "homeLockHint"
            Layout.alignment: Qt.AlignHCenter
            visible: page.clampLocked && page.machine.state !== Machine.Homing
            text: qsTr("Kilitli: referans aramak için önce mengeneyi açın")
            font.pixelSize: Theme.fontNormal
            font.bold: true
            color: Theme.activeText
        }
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

            // Referans noktasında eksene yazılacak değer
            Text {
                text: "→ " + step.axis.homePosition.toFixed(2) + (step.axis.rotary ? "°" : " mm")
                font.pixelSize: Theme.fontSmall
                color: Theme.textMuted
            }

            Text {
                Layout.preferredWidth: 76
                horizontalAlignment: Text.AlignRight
                text: step.axis.homed ? qsTr("Tamam")
                                      : step.axis.homing ? qsTr("Aranıyor…") : qsTr("Bekliyor")
                font.pixelSize: Theme.fontNormal
                font.bold: step.axis.homing
                color: step.axis.homed ? Theme.ok : Theme.textMuted
            }
        }
    }
}
