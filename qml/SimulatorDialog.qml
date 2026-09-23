// Satırlar bu dosyadaki "dialog" kimliğine güvenle erişebilsin.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

// Sanal makine · arıza denemesi: YALNIZCA DEMO İÇİNDİR.
//
// Gerçek makinede arızayı makinenin kendisi üretir; orada bu pencere hiç görünmez
// (main.cpp "simulator" olarak boş verir). Demoda arıza yönetimini canlı göstermek için:
//   acil stop   → bütün hareket kesilir, pompa durur, arıza RESET bekler
//   hat kaçağı  → pompa çalışsa da basınç düşer, döngü basınç arızasıyla durur
//   sensör arızası → mengene kapanır ama sensör gelmez; döngü zaman aşımıyla durur ve
//                    arıza mesajı IO TEST'te teşhis edilir
T.Popup {
    id: dialog

    required property SimControls simulator

    width: Math.min(720, (parent ? parent.width : 800) - 80)

    parent: T.Overlay.overlay
    anchors.centerIn: parent
    modal: true
    focus: true
    padding: 20
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside

    // Şablon (Templates) popup boyutunu kendisi hesaplamaz: içeriğe göre biz veririz.
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    T.Overlay.modal: Rectangle {
        color: "#73000000"
    }

    background: Rectangle {
        radius: 10
        color: Theme.panel
        border.color: Theme.panelBorder
    }

    contentItem: ColumnLayout {
        spacing: 10

        Text {
            objectName: "simulatorTitle"
            text: qsTr("Sanal makine · arıza denemesi")
            font.pixelSize: Theme.fontTitle
            font.bold: true
            color: Theme.text
        }

        Text {
            Layout.fillWidth: true
            text: qsTr("Bu pencere yalnızca sanal makinede vardır: gerçek makinede arızayı "
                       + "makinenin kendisi üretir. Buradaki denemeler ekranın arızaları nasıl "
                       + "gösterdiğini ve nasıl silindiğini denemek içindir.")
            font.pixelSize: 13
            color: Theme.textMuted
            wrapMode: Text.WordWrap
        }

        FaultRow {
            objectName: "simEmergency"
            title: qsTr("ACİL STOP")
            note: qsTr("Bütün hareket kesilir, pompa durur, referans düşer; arıza RESET bekler.")
            active: dialog.simulator.emergencyStop
            activeText: qsTr("BIRAK")
            idleText: qsTr("BAS")
            onToggled: on => dialog.simulator.pressEmergencyStop(on)
        }

        FaultRow {
            objectName: "simPressure"
            title: qsTr("HAT KAÇAĞI · BASINÇ KAYBI")
            note: qsTr("Pompa çalışsa da basınç düşer; üretim sürerken basınç arızası verir.")
            active: dialog.simulator.pressureLoss
            activeText: qsTr("DÜZELT")
            idleText: qsTr("BAŞLAT")
            onToggled: on => dialog.simulator.setPressureLoss(on)
        }

        FaultRow {
            objectName: "simSensor"
            title: qsTr("SENSÖR ARIZASI · %1").arg(dialog.simulator.sensorLabel)
            note: qsTr("Sensör hiç gelmez: mengene kapanır ama makine göremez, döngü zaman "
                       + "aşımıyla durur. Sebebi IO TEST'te görünür.")
            active: dialog.simulator.sensorFault
            activeText: qsTr("DÜZELT")
            idleText: qsTr("BOZ")
            onToggled: on => dialog.simulator.setSensorFault(on)
        }

        HmiButton {
            objectName: "simulatorClose"
            Layout.alignment: Qt.AlignRight
            Layout.topMargin: 4
            implicitWidth: 140
            implicitHeight: 52
            font.pixelSize: 16
            text: qsTr("KAPAT")
            onClicked: dialog.close()
        }
    }

    // Bir deneme: adı, ne olacağı ve açıp kapatan butonu.
    component FaultRow: Rectangle {
        id: faultRow

        required property string title
        required property string note
        required property bool active
        required property string activeText // deneme açıkken butonun yazısı
        required property string idleText   // kapalıyken butonun yazısı

        signal toggled(on: bool)

        Layout.fillWidth: true
        implicitHeight: 76
        radius: Theme.radius
        color: faultRow.active ? "#f9e6e6" : Theme.field
        border.color: faultRow.active ? Theme.danger : Theme.panelBorder

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 10
            spacing: 10

            Rectangle {
                implicitWidth: 12
                implicitHeight: 12
                radius: 6
                color: faultRow.active ? Theme.danger : Theme.idle
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    objectName: "simRowTitle"
                    Layout.fillWidth: true
                    text: faultRow.title
                    font.pixelSize: 15
                    font.bold: true
                    color: faultRow.active ? Theme.danger : Theme.text
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: faultRow.note
                    font.pixelSize: 13
                    color: Theme.textMuted
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            HmiButton {
                objectName: "simToggle"
                implicitWidth: 120
                implicitHeight: 52
                padding: 6
                font.pixelSize: 15
                text: faultRow.active ? faultRow.activeText : faultRow.idleText
                accent: faultRow.active ? Theme.ok : Theme.danger
                onClicked: faultRow.toggled(!faultRow.active)
            }
        }
    }
}
