import QtQuick
import QtQuick.Templates as T

// Dokunmatik ekran için büyük buton.
//   accent: butonun anlamını taşıyan renk (ör. STOP için kırmızı)
//   filled: true ise buton bu renkle dolu çizilir
T.Button {
    id: control

    property color accent: Theme.text
    property bool filled: false

    implicitWidth: Math.max(160, implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: 64
    padding: 12

    font.pixelSize: 18
    font.bold: true

    // Devre dışıyken soluk görünsün.
    opacity: enabled ? 1.0 : 0.4

    contentItem: Text {
        text: control.text
        font: control.font
        color: control.filled ? "white" : control.accent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: Theme.radius
        color: control.filled
               ? (control.down ? Qt.darker(control.accent, 1.3) : control.accent)
               : (control.down ? Theme.buttonDown : Theme.buttonFace)
        border.width: control.filled ? 0 : 2
        border.color: control.accent
    }
}
