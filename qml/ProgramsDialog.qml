// Liste satırları bu dosyadaki "dialog" ve "list" kimliklerine güvenle erişebilsin.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

// Programlar penceresi: klasördeki kayıtlı programlar.
// Bir programa dokunup AÇ'a basılır (ya da iki kez dokunulur). YENİ boş bir program
// başlatır, FARKLI KAYDET açık programı yeni bir adla kaydeder, SİL dosyayı siler.
// Pencere yalnızca isteği bildirir; soruları ve işlemleri ProgramManager yürütür.
T.Popup {
    id: dialog

    required property ProgramStore store

    // Seçili program (boş: seçim yok) ve açılabilir olup olmadığı
    property string selectedName: ""
    property bool selectedReadable: false

    signal openRequested(string name)
    signal newRequested()
    signal saveAsRequested()
    signal removeRequested(string name)

    function selectRow(name: string, readable: bool) {
        dialog.selectedName = name
        dialog.selectedReadable = readable
    }

    function clearSelection() {
        dialog.selectRow("", false)
    }

    function requestOpen() {
        if (dialog.selectedName.length > 0 && dialog.selectedReadable)
            dialog.openRequested(dialog.selectedName)
    }

    // Pencere açılırken klasör yeniden okunur; ekrandaki program seçili gelir.
    onAboutToShow: {
        dialog.store.refresh()
        if (dialog.store.currentName.length > 0)
            dialog.selectRow(dialog.store.currentName, true)
        else
            dialog.clearSelection()
    }

    width: Math.min(760, (parent ? parent.width : 800) - 80)
    height: Math.min(560, (parent ? parent.height : 600) - 80)

    parent: T.Overlay.overlay
    anchors.centerIn: parent
    modal: true
    focus: true
    padding: 20
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside

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

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: qsTr("Programlar")
                font.pixelSize: Theme.fontTitle
                font.bold: true
                color: Theme.text
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: qsTr("%1 program").arg(dialog.store.count)
                font.pixelSize: Theme.fontNormal
                color: Theme.textMuted
            }
        }

        // Programların durduğu klasör: dosyalar buradan kopyalanıp taşınabilir.
        Text {
            objectName: "programsFolder"
            Layout.fillWidth: true
            text: qsTr("Klasör: %1").arg(dialog.store.folder)
            font.pixelSize: 13
            color: Theme.textMuted
            elide: Text.ElideMiddle
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: list

                objectName: "programsList"
                anchors.fill: parent
                anchors.rightMargin: 10
                clip: true
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds
                model: dialog.store

                // Bir satır: ad, "açık" işareti, adım sayısı, son kayıt zamanı.
                delegate: Rectangle {
                    id: row

                    required property string name
                    required property int stepCount
                    required property date savedAt
                    required property bool readable
                    required property bool current

                    readonly property bool selected: dialog.selectedName === row.name

                    objectName: "programRow:" + row.name
                    width: list.width
                    height: 52
                    radius: Theme.radius
                    color: row.selected ? Theme.selection : Theme.field
                    border.width: row.selected ? 2 : 1
                    border.color: row.selected ? Theme.navSelected : Theme.panelBorder

                    TapHandler {
                        onTapped: dialog.selectRow(row.name, row.readable)
                        onDoubleTapped: {
                            dialog.selectRow(row.name, row.readable)
                            dialog.requestOpen()
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        Text {
                            Layout.fillWidth: true
                            text: row.name
                            font.pixelSize: Theme.fontNormal
                            font.bold: true
                            color: row.readable ? Theme.text : Theme.danger
                            elide: Text.ElideRight
                        }

                        // Ekranda açık olan program
                        Rectangle {
                            visible: row.current
                            implicitWidth: openTag.implicitWidth + 16
                            implicitHeight: 24
                            radius: 12
                            color: Theme.navSelected

                            Text {
                                id: openTag

                                anchors.centerIn: parent
                                text: qsTr("AÇIK")
                                font.pixelSize: 12
                                font.bold: true
                                color: "white"
                            }
                        }

                        Text {
                            Layout.preferredWidth: 100
                            horizontalAlignment: Text.AlignRight
                            text: row.readable ? qsTr("%1 adım").arg(row.stepCount) : qsTr("okunamıyor")
                            font.pixelSize: Theme.fontSmall
                            font.bold: !row.readable
                            color: row.readable ? Theme.textMuted : Theme.danger
                        }

                        Text {
                            Layout.preferredWidth: 130
                            horizontalAlignment: Text.AlignRight
                            text: Qt.formatDateTime(row.savedAt, "dd.MM.yyyy HH:mm")
                            font.pixelSize: Theme.fontSmall
                            color: Theme.textMuted
                        }
                    }
                }
            }

            // Kaydırma göstergesi: liste sığmıyorsa nerede olunduğunu gösterir.
            Rectangle {
                anchors.left: list.right
                anchors.leftMargin: 3
                y: list.visibleArea.yPosition * list.height
                width: 4
                height: list.visibleArea.heightRatio * list.height
                radius: 2
                color: Theme.idle
                visible: list.contentHeight > list.height
            }

            Text {
                objectName: "programsEmpty"
                anchors.centerIn: parent
                visible: dialog.store.count === 0
                text: qsTr("Kayıtlı program yok.")
                font.pixelSize: Theme.fontNormal
                color: Theme.textMuted
            }
        }

        // Son işlem başarısızsa nedeni
        Text {
            objectName: "programsError"
            Layout.fillWidth: true
            visible: dialog.store.lastError.length > 0
            text: dialog.store.lastError
            font.pixelSize: Theme.fontSmall
            font.bold: true
            color: Theme.danger
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            HmiButton {
                objectName: "programsNew"
                implicitWidth: 100
                implicitHeight: 56
                font.pixelSize: 16
                text: qsTr("YENİ")
                onClicked: dialog.newRequested()
            }

            HmiButton {
                objectName: "programsSaveAs"
                implicitWidth: 170
                implicitHeight: 56
                font.pixelSize: 16
                text: qsTr("FARKLI KAYDET")
                onClicked: dialog.saveAsRequested()
            }

            HmiButton {
                objectName: "programsRemove"
                implicitWidth: 90
                implicitHeight: 56
                font.pixelSize: 16
                text: qsTr("SİL")
                accent: Theme.danger
                enabled: dialog.selectedName.length > 0
                onClicked: dialog.removeRequested(dialog.selectedName)
            }

            Item {
                Layout.fillWidth: true
            }

            HmiButton {
                objectName: "programsClose"
                implicitWidth: 110
                implicitHeight: 56
                font.pixelSize: 16
                text: qsTr("KAPAT")
                onClicked: dialog.close()
            }

            HmiButton {
                objectName: "programsOpen"
                implicitWidth: 110
                implicitHeight: 56
                font.pixelSize: 16
                text: qsTr("AÇ")
                accent: Theme.ok
                filled: true
                enabled: dialog.selectedName.length > 0 && dialog.selectedReadable
                onClicked: dialog.requestOpen()
            }
        }
    }
}
