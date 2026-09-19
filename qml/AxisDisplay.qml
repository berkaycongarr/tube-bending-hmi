import QtQuick
import QtQuick.Layouts

// Bir eksenin anlık konumunu gösteren kutu.
// Sol üstteki nokta referans durumunu gösterir:
//   gri = referanssız, turuncu (yanıp söner) = referans arıyor, yeşil = referanslı
Rectangle {
    id: box

    required property Axis axis
    property string title

    objectName: "axisDisplay" + box.axis.name
    implicitWidth: 190
    implicitHeight: 72
    radius: Theme.radius
    color: Theme.panel
    // Eksen referans ararken ya da hareket ederken çerçeve turuncu olur.
    border.color: box.axis.homing || box.axis.moving ? Theme.active : Theme.panelBorder
    border.width: box.axis.homing || box.axis.moving ? 2 : 1

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 8
        anchors.bottomMargin: 6
        spacing: 0

        RowLayout {
            spacing: 8

            Rectangle {
                id: dot

                implicitWidth: 10
                implicitHeight: 10
                radius: 5
                color: box.axis.homed ? Theme.ok : box.axis.homing ? Theme.active : Theme.idle

                // Referans ararken yanıp söner; arama bitince hemen sabitlenir.
                SequentialAnimation {
                    running: box.axis.homing
                    loops: Animation.Infinite
                    onStopped: dot.opacity = 1.0

                    NumberAnimation { target: dot; property: "opacity"; to: 0.2; duration: 350 }
                    NumberAnimation { target: dot; property: "opacity"; to: 1.0; duration: 350 }
                }
            }

            Text {
                text: box.axis.name
                font.pixelSize: Theme.fontSmall
                font.bold: true
                color: Theme.text
            }

            Text {
                Layout.fillWidth: true
                text: box.title
                font.pixelSize: Theme.fontSmall
                color: Theme.textMuted
                elide: Text.ElideRight
            }
        }

        RowLayout {
            spacing: 4

            // Değer sağa yaslı. Kutu daralırsa (ör. 1024 px ekranda) yazı taşmak
            // yerine sığana kadar küçülür. Derece işareti rakamlarla aynı boyda.
            Text {
                objectName: "axisValue"
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignBaseline
                horizontalAlignment: Text.AlignRight
                text: box.axis.position.toFixed(2) + (box.axis.rotary ? "°" : "")
                font.pixelSize: Theme.fontLarge
                font.bold: true
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 16
                color: Theme.text
            }

            // Doğrusal eksenin birimi küçük yazılır.
            Text {
                Layout.alignment: Qt.AlignBaseline
                visible: !box.axis.rotary
                text: "mm"
                font.pixelSize: Theme.fontSmall
                color: Theme.textMuted
            }
        }
    }
}
