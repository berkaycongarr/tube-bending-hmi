// Satırlar bu dosyadaki "table" ve "list" kimliklerine güvenle erişebilsin.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

// Program tablosu: NO, KOMUT ve üç değer sütunu (UZUNLUK, BÜKÜM, ROTASYON).
// Sütunlar müşterinin mevcut ekranındaki gibi; birimler başlıkta yazılı olduğu
// için hücrelerde yalnızca sayı görünür.
//
// TASARIM sayfasında düzenlenebilir (editable): değere dokununca valueClicked
// bildirilir, sayfa tuş takımını açar. ÜRETİM sayfasında yalnızca gösterir.
// İki sayfa aynı programı (aynı modeli) gösterir: birinde yapılan değişiklik
// öbüründe hemen görünür.
Item {
    id: table

    required property BendProgram program
    property bool editable: false
    property int selectedRow: -1 // seçili satır (-1: seçim yok)
    property string emptyText: qsTr("Program boş.")

    signal rowTapped(int row)
    signal valueClicked(int row, int command, real value)

    function commandName(command: int): string {
        switch (command) {
        case BendProgram.Bend:
            return qsTr("BÜK")
        case BendProgram.Rotate:
            return qsTr("ROTASYON")
        default:
            return qsTr("İLERLE")
        }
    }

    // Satırı görünür yap (liste uzunsa kaydırır).
    function showRow(row: int) {
        if (row >= 0)
            list.positionViewAtIndex(row, ListView.Contain)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 44
            radius: Theme.radius
            color: Theme.buttonFace

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 6
                spacing: 8

                HeaderText {
                    Layout.preferredWidth: 30
                    text: qsTr("NO")
                }

                HeaderText {
                    Layout.preferredWidth: 104
                    text: qsTr("KOMUT")
                }

                ColumnHeader {
                    title: qsTr("UZUNLUK")
                    unit: "mm"
                }

                ColumnHeader {
                    title: qsTr("BÜKÜM")
                    unit: "°"
                }

                ColumnHeader {
                    title: qsTr("ROTASYON")
                    unit: "°"
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: list

                objectName: "programList"
                anchors.fill: parent
                clip: true
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds
                model: table.program

                // Bir satır: numara, komut ve değer. Değer yalnızca komutun sütununda görünür.
                delegate: Rectangle {
                    id: stepRow

                    required property int index
                    required property int command
                    required property real value
                    required property bool valid

                    readonly property bool selected: table.selectedRow === stepRow.index

                    objectName: "step" + stepRow.index
                    width: list.width
                    height: 48
                    radius: Theme.radius
                    color: stepRow.selected ? Theme.selection : Theme.field
                    border.width: stepRow.selected ? 2 : 1
                    border.color: stepRow.selected ? Theme.navSelected : Theme.panelBorder

                    TapHandler {
                        onTapped: table.rowTapped(stepRow.index)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 6
                        spacing: 8

                        Text {
                            Layout.preferredWidth: 30
                            text: stepRow.index + 1
                            font.pixelSize: Theme.fontNormal
                            color: Theme.textMuted
                        }

                        Text {
                            Layout.preferredWidth: 104
                            text: table.commandName(stepRow.command)
                            font.pixelSize: Theme.fontNormal
                            font.bold: true
                            color: Theme.text
                        }

                        // Üç değer sütunu: İLERLE, BÜK, ROTASYON sırasıyla
                        Repeater {
                            model: 3

                            delegate: Item {
                                id: cell

                                required property int index

                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.fillHeight: true

                                // Düzenlenebilirken dokunulabilir bir kutu, değilse düz yazı.
                                T.Button {
                                    id: valueButton

                                    objectName: "value" + stepRow.index
                                    anchors.fill: parent
                                    anchors.topMargin: 5
                                    anchors.bottomMargin: 5
                                    visible: cell.index === stepRow.command
                                    enabled: table.editable
                                    rightPadding: 10
                                    text: stepRow.value.toFixed(2)
                                    onClicked: table.valueClicked(stepRow.index, stepRow.command, stepRow.value)

                                    contentItem: Text {
                                        text: valueButton.text
                                        font.pixelSize: Theme.fontNormal
                                        font.bold: true
                                        color: stepRow.valid ? Theme.text : Theme.danger
                                        horizontalAlignment: Text.AlignRight
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    background: Rectangle {
                                        visible: table.editable || !stepRow.valid
                                        radius: Theme.radius
                                        color: valueButton.down ? Theme.buttonDown : Theme.field
                                        border.width: stepRow.valid ? 1 : 2
                                        border.color: stepRow.valid ? Theme.panelBorder : Theme.danger
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Kaydırma göstergesi: liste sığmıyorsa nerede olunduğunu gösterir.
            // Satırların üstüne binmesin diye listenin hemen sağında durur.
            Rectangle {
                anchors.left: list.right
                anchors.leftMargin: 2
                y: list.visibleArea.yPosition * list.height
                width: 4
                height: list.visibleArea.heightRatio * list.height
                radius: 2
                color: Theme.idle
                visible: list.contentHeight > list.height
            }

            Text {
                objectName: "emptyHint"
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 40)
                visible: table.program.count === 0
                text: table.emptyText
                font.pixelSize: Theme.fontNormal
                color: Theme.textMuted
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }

    // Tablo başlığındaki sütun adı
    component HeaderText: Text {
        font.pixelSize: 13
        font.bold: true
        color: Theme.textMuted
    }

    // Değer sütununun başlığı: üstte ad, altta birim; sağa yaslı (sayılar gibi).
    component ColumnHeader: Item {
        id: header

        required property string title
        required property string unit

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.fillHeight: true

        Column {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter

            HeaderText {
                anchors.right: parent.right
                text: header.title
            }

            HeaderText {
                anchors.right: parent.right
                text: header.unit
                font.bold: false
            }
        }
    }
}
