// Liste satırları bu dosyadaki "dialog" ve "list" kimliklerine güvenle erişebilsin.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

// Arıza geçmişi: duran (silinmemiş) ve silinmiş arızalar, en yenisi üstte.
// Her kayıtta oluştuğu an, ne olduğu ve nereye bakılacağı yazar; bakımcı makinenin
// başına geçmeden önce neyin ne zaman olduğunu buradan görür.
// RESET, sebebi geçmiş arızaları siler (üst şerittekiyle aynı komut).
T.Popup {
    id: dialog

    required property Machine machine

    function rowState(state: int, clearedTime: var): string {
        if (state === AlarmList.Active)
            return qsTr("sürüyor")
        if (state === AlarmList.Latched)
            return qsTr("RESET bekliyor")
        return qsTr("silindi · %1").arg(Qt.formatDateTime(clearedTime, "HH:mm:ss"))
    }

    width: Math.min(820, (parent ? parent.width : 900) - 80)
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
                objectName: "alarmsTitle"
                text: qsTr("Arıza geçmişi")
                font.pixelSize: Theme.fontTitle
                font.bold: true
                color: Theme.text
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                objectName: "alarmsCount"
                text: dialog.machine.alarmCount > 0
                      ? qsTr("%1 arıza duruyor · %2 kayıt").arg(dialog.machine.alarmCount)
                                                           .arg(dialog.machine.alarms.count)
                      : qsTr("%1 kayıt").arg(dialog.machine.alarms.count)
                font.pixelSize: Theme.fontNormal
                font.bold: dialog.machine.alarmCount > 0
                color: dialog.machine.alarmCount > 0 ? Theme.danger : Theme.textMuted
            }
        }

        Text {
            objectName: "alarmsEmpty"
            Layout.fillWidth: true
            visible: dialog.machine.alarms.count === 0
            text: qsTr("Arıza kaydı yok.")
            font.pixelSize: Theme.fontNormal
            color: Theme.textMuted
        }

        ListView {
            id: list

            objectName: "alarmsList"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: dialog.machine.alarms

            delegate: Rectangle {
                id: row

                required property string code
                required property string title
                required property string detail
                required property var time
                required property var clearedTime
                required property int alarmState

                readonly property bool unresolved: row.alarmState !== AlarmList.Cleared

                objectName: "alarm:" + row.code
                width: list.width
                height: 64
                radius: Theme.radius
                color: row.unresolved ? "#14c62828" : Theme.field
                border.color: row.unresolved ? Theme.danger : Theme.panelBorder

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    // Duran arıza kırmızı, silinmiş arıza gri
                    Rectangle {
                        implicitWidth: 12
                        implicitHeight: 12
                        radius: 6
                        color: row.unresolved ? Theme.danger : Theme.idle
                    }

                    Text {
                        objectName: "alarmTime"
                        Layout.preferredWidth: 120
                        text: Qt.formatDateTime(row.time, "dd.MM HH:mm:ss")
                        font.pixelSize: 13
                        color: Theme.textMuted
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            objectName: "alarmRowTitle"
                            Layout.fillWidth: true
                            text: row.title
                            font.pixelSize: 15
                            font.bold: true
                            color: row.unresolved ? Theme.danger : Theme.text
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.detail
                            font.pixelSize: 13
                            color: Theme.textMuted
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        objectName: "alarmRowState"
                        Layout.preferredWidth: 130
                        horizontalAlignment: Text.AlignRight
                        text: dialog.rowState(row.alarmState, row.clearedTime)
                        font.pixelSize: 13
                        font.bold: row.unresolved
                        color: row.unresolved ? Theme.danger : Theme.textMuted
                        elide: Text.ElideRight
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: qsTr("RESET yalnızca sebebi geçmiş arızaları siler; hiçbir şeyi hareket "
                           + "ettirmez. Üretim, arıza silindikten sonra BAŞLAT ile sürer.")
                font.pixelSize: 13
                color: Theme.textMuted
                wrapMode: Text.WordWrap
            }

            HmiButton {
                objectName: "alarmsReset"
                implicitWidth: 150
                implicitHeight: 52
                font.pixelSize: 16
                text: qsTr("RESET")
                accent: Theme.danger
                filled: true
                enabled: dialog.machine.canResetAlarms
                onClicked: dialog.machine.resetAlarms()
            }

            HmiButton {
                objectName: "alarmsClose"
                implicitWidth: 140
                implicitHeight: 52
                font.pixelSize: 16
                text: qsTr("KAPAT")
                onClicked: dialog.close()
            }
        }
    }
}
