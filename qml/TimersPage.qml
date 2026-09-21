// Liste satırları "page", "list" ve "lockBar" kimliklerine güvenle erişebilsin.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// ZAMANLAR sayfası: makinenin süreleri (müşterinin menüsündeki ZAMANLAR).
// Bekleme süreleri ve zaman aşımları makinenin belleğinde durur (gerçek makinede
// PLC); ekran gösterir ve değiştirir. Değerleri herkes görür, değiştirmek için
// ayarcı şifresi gerekir. Değişen süre hemen geçerli olur.
Rectangle {
    id: page

    required property Machine machine
    required property AccessControl access

    // Tuş takımında düzenlenen sürenin anahtarı
    property string editKey: ""

    function format(value: real, decimals: int, unit: string): string {
        return value.toFixed(decimals) + " " + unit
    }

    // Bir süreyi düzenle: tuş takımı aralığı ve varsayılanı gösterir.
    function edit(key: string) {
        const p = page.machine.timers.get(page.machine.timers.indexOf(key))
        if (p.key === undefined)
            return
        page.editKey = key
        keypad.title = p.title
        keypad.unit = p.unit
        keypad.minimum = p.minimum
        keypad.maximum = p.maximum
        keypad.defaultValue = p.defaultValue
        keypad.note = qsTr("Şu anki değer: %1").arg(page.format(p.value, p.decimals, p.unit))
        keypad.open()
    }

    // Şifre soruldu ve doğruysa (ya da kilit zaten açıksa) istenen iş yapılır.
    function run(tag: string) {
        const colon = tag.indexOf(":")
        const action = tag.slice(0, colon), key = tag.slice(colon + 1)
        if (action === "edit")
            page.edit(key)
        else if (action === "reset")
            page.machine.timers.reset(key)
    }

    radius: Theme.radius
    color: Theme.panel
    border.color: Theme.panelBorder

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: qsTr("Zamanlar")
                font.pixelSize: Theme.fontTitle
                font.bold: true
                color: Theme.text
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Makinenin bekleme süreleri ve zaman aşımları")
                font.pixelSize: Theme.fontNormal
                color: Theme.textMuted
                elide: Text.ElideRight
            }
        }

        LockBar {
            id: lockBar

            Layout.fillWidth: true
            access: page.access
            onGranted: tag => page.run(tag)
        }

        ListView {
            id: list

            objectName: "timerList"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: page.machine.timers

            // Bir süre: adı ve ne işe yaradığı, değeri (varsayılanı üstünde), varsayılana dön.
            delegate: Rectangle {
                id: row

                required property string key
                required property string title
                required property string note
                required property string unit
                required property real value
                required property real defaultValue
                required property int decimals
                required property bool modified

                objectName: "timer:" + row.key
                width: list.width
                height: 68
                radius: Theme.radius
                color: Theme.field
                border.color: Theme.panelBorder

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 8
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            objectName: "timerTitle"
                            Layout.fillWidth: true
                            text: row.title
                            font.pixelSize: Theme.fontNormal
                            font.bold: true
                            color: Theme.text
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.note
                            font.pixelSize: 13
                            color: Theme.textMuted
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }

                    // Değer: dokununca (şifre sorulur) tuş takımı açılır.
                    // Varsayılandan farklıysa başlık turuncu: bu süre değiştirilmiş.
                    ValueField {
                        objectName: "timerValue"
                        implicitWidth: 176
                        implicitHeight: 56
                        topPadding: 5
                        bottomPadding: 5
                        caption: qsTr("Varsayılan %1").arg(page.format(row.defaultValue, row.decimals, row.unit))
                        captionColor: row.modified ? Theme.activeText : Theme.textMuted
                        text: page.format(row.value, row.decimals, row.unit)
                        onClicked: lockBar.request("edit:" + row.key)
                    }

                    HmiButton {
                        objectName: "timerReset"
                        implicitWidth: 56
                        implicitHeight: 52
                        padding: 4
                        font.pixelSize: 22
                        text: "↺"
                        enabled: row.modified
                        onClicked: lockBar.request("reset:" + row.key)
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: qsTr("Değişen süre hemen geçerli olur; döngü sürerken değiştirilirse sıradaki aşamada "
                       + "kullanılır. Süreler makinenin belleğinde saklanır. ↺ varsayılana döndürür.")
            font.pixelSize: 13
            color: Theme.textMuted
            wrapMode: Text.WordWrap
        }
    }

    NumericKeypad {
        id: keypad

        onValueEntered: value => {
            if (page.machine.timers.setValue(page.editKey, value))
                page.access.keepAlive()
        }
    }
}
