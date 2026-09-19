import QtQuick
import QtQuick.Templates as T

// Değer alanı: bir yazı kutusu gibi görünür, dokununca tuş takımı açılır.
//   caption: üstteki küçük başlık (ör. "Hedef")
//   text:    gösterilen değer
T.Button {
    id: control

    property string caption
    property color captionColor: Theme.textMuted

    implicitWidth: 150
    implicitHeight: 68
    leftPadding: 12
    rightPadding: 12
    topPadding: 8
    bottomPadding: 8

    // Devre dışıyken soluk görünsün.
    opacity: enabled ? 1.0 : 0.4

    contentItem: Column {
        spacing: 2

        Text {
            text: control.caption
            font.pixelSize: 13
            font.bold: true
            color: control.captionColor
        }

        Text {
            width: parent.width
            text: control.text
            font.pixelSize: 20
            font.bold: true
            color: Theme.text
            elide: Text.ElideRight
        }
    }

    background: Rectangle {
        radius: Theme.radius
        color: Theme.field
        border.width: control.down ? 2 : 1
        border.color: control.down ? Theme.text : Theme.panelBorder
    }
}
