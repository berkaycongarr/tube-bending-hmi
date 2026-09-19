import QtQuick
import QtQuick.Templates as T

// Sol menüdeki sayfa butonu. Seçili sayfa koyu zeminle gösterilir.
// Menü butonları komut butonlarından (STOP, HOME) bilerek farklı görünür:
// biri sayfa değiştirir, diğeri makineye iş yaptırır.
T.Button {
    id: control

    property bool selected: false

    implicitWidth: 140
    implicitHeight: 60
    leftPadding: 16
    rightPadding: 12

    font.pixelSize: Theme.fontNormal
    font.bold: true

    contentItem: Text {
        text: control.text
        font: control.font
        color: control.selected ? "white" : Theme.text
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: Theme.radius
        color: control.selected ? Theme.navSelected
                                : (control.down ? Theme.buttonDown : "transparent")
    }
}
