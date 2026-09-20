import QtQuick
import QtQuick.Templates as T

// "Kalıcı buton": bir basış silindiri iş konumuna gönderir, ikinci basış geri alır.
// Buton komutu değil, sensörlerin bildirdiği durumu gösterir: silindir yoldayken
// "KAPANIYOR…" yazar ve kenarlığı yanıp söner; yolunu bitirince "KAPALI" olur.
// Silindir kilitliyse buton basılmaz ve nedenini yazar.
T.Button {
    id: control

    required property Machine machine
    required property Actuator actuator
    property string title          // ör. "MENGENE"
    property string onText         // iş konumu, ör. "KAPALI"
    property string offText        // bekleme konumu, ör. "AÇIK"
    property string turningOnText  // ör. "KAPANIYOR…"
    property string turningOffText // ör. "AÇILIYOR…"

    readonly property bool isOn: control.actuator.state === Actuator.On
    readonly property bool inMotion: control.actuator.state === Actuator.TurningOn
                                     || control.actuator.state === Actuator.TurningOff
    readonly property bool locked: control.actuator.interlock !== Actuator.NoInterlock

    readonly property string stateText: {
        switch (control.actuator.state) {
        case Actuator.On:
            return control.onText
        case Actuator.TurningOn:
            return control.turningOnText
        case Actuator.TurningOff:
            return control.turningOffText
        default:
            return control.offText
        }
    }

    readonly property string lockText: {
        switch (control.actuator.interlock) {
        case Actuator.PumpOff:
            return qsTr("Pompa çalışmıyor")
        case Actuator.AxesMoving:
            return qsTr("Eksenler hareketli")
        case Actuator.CycleRunning:
            return qsTr("Döngü çalışıyor")
        default:
            return ""
        }
    }

    implicitWidth: 170
    implicitHeight: 104
    padding: 12
    enabled: !control.locked

    // Komutu tersine çevir: makine şu an "kapat" diyorsa "aç", değilse "kapat".
    onClicked: control.machine.setActuator(control.actuator, !control.actuator.command)

    contentItem: Column {
        spacing: 2

        Text {
            text: control.title
            font.pixelSize: Theme.fontSmall
            font.bold: true
            color: control.isOn ? "#c9d1d9" : Theme.textMuted
        }

        Text {
            width: parent.width
            text: control.stateText
            font.pixelSize: Theme.fontTitle
            font.bold: true
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 14
            color: control.isOn ? "white" : control.inMotion ? Theme.activeText : Theme.text
        }

        Text {
            width: parent.width
            text: control.lockText
            visible: control.locked
            font.pixelSize: 13
            font.bold: true
            color: control.isOn ? "#ffcf8a" : Theme.activeText
            elide: Text.ElideRight
        }
    }

    background: Rectangle {
        radius: Theme.radius
        color: control.isOn ? (control.down ? Qt.darker(Theme.navSelected, 1.2) : Theme.navSelected)
                            : (control.down ? Theme.buttonDown : Theme.buttonFace)
        border.width: 2
        border.color: control.isOn ? Theme.navSelected : Theme.panelBorder

        // Silindir yoldayken turuncu kenarlık yanıp söner.
        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: "transparent"
            border.width: 3
            border.color: Theme.active
            visible: control.inMotion

            SequentialAnimation on opacity {
                running: control.inMotion
                loops: Animation.Infinite

                NumberAnimation { to: 0.25; duration: 300 }
                NumberAnimation { to: 1.0; duration: 300 }
            }
        }
    }
}
