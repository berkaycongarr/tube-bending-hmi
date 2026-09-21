// Tablo hücreleri ve küçük bileşenler "page" ve "lockBar" kimliklerine güvenle erişebilsin.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

// AYARLAR sayfası: makinenin ayarları (müşterinin menüsündeki AYARLAR).
//   eksenler: yazılım limitleri (alt, üst), jog hızları (yavaş, hızlı), konumlama hızı
//   döngü:    boru alma konumu X
//   şifre:    ayarcı şifresini değiştirme
// Değerler makinenin belleğinde durur (gerçek makinede PLC). Değerleri herkes görür,
// değiştirmek için ayarcı şifresi gerekir. Döngü sürerken ya da referans aranırken
// makine ayarları kilitler: makine o değerlerle çalışıyor.
Rectangle {
    id: page

    required property Machine machine
    required property AccessControl access

    // Tuş takımında düzenlenen ayarın anahtarı
    property string editKey: ""

    // Şifre değiştirme: 1 yeni şifre, 2 tekrarı; ilk yazılan saklanır.
    property int pinStep: 0
    property string firstPin: ""
    property string pinMessage: "" // son şifre değişikliğinin sonucu

    readonly property ParameterList settings: page.machine.settings

    function format(value: real, decimals: int, unit: string): string {
        return value.toFixed(decimals) + (unit === "°" ? "°" : " " + unit)
    }

    // Bir ayarı düzenle: tuş takımı aralığı (öbür değerlere göre) ve varsayılanı gösterir.
    function edit(key: string) {
        const p = page.settings.get(page.settings.indexOf(key))
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
        if (tag === "pin") {
            page.pinMessage = ""
            page.pinStep = 1
            pinPad.title = qsTr("Yeni şifre")
            pinPad.open()
        } else if (tag === "defaults") {
            defaultsConfirm.open()
        } else if (tag.startsWith("edit:")) {
            page.edit(tag.slice(5))
        }
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
                text: qsTr("Ayarlar")
                font.pixelSize: Theme.fontTitle
                font.bold: true
                color: Theme.text
            }

            // Makine ayarları kilitlediyse neden kilitli olduğu yazar.
            Text {
                objectName: "settingsSubtitle"
                Layout.fillWidth: true
                text: page.settings.locked ? page.settings.lockReason
                                           : qsTr("Makinenin konumları, limitleri ve hızları")
                font.pixelSize: page.settings.locked ? Theme.fontSmall : Theme.fontNormal
                font.bold: page.settings.locked
                color: page.settings.locked ? Theme.activeText : Theme.textMuted
                elide: Text.ElideRight
            }

            HmiButton {
                objectName: "settingsDefaults"
                implicitWidth: 196
                implicitHeight: 40
                padding: 6
                font.pixelSize: 14
                text: qsTr("VARSAYILANLARA DÖN")
                enabled: !page.settings.locked
                onClicked: lockBar.request("defaults")
            }
        }

        LockBar {
            id: lockBar

            Layout.fillWidth: true
            access: page.access
            onGranted: tag => page.run(tag)
        }

        // ---------------- Eksenler ----------------
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: axisGrid.implicitHeight + 24
            radius: Theme.radius
            color: Theme.field
            border.color: Theme.panelBorder

            GridLayout {
                id: axisGrid

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                columns: 6
                rowSpacing: 6
                columnSpacing: 8

                HeaderText {
                    Layout.fillWidth: false
                    Layout.preferredWidth: 118
                    horizontalAlignment: Text.AlignLeft
                    text: qsTr("EKSEN")
                }
                HeaderText { text: qsTr("ALT LİMİT") }
                HeaderText { text: qsTr("ÜST LİMİT") }
                HeaderText { text: qsTr("JOG YAVAŞ") }
                HeaderText { text: qsTr("JOG HIZLI") }
                HeaderText { text: qsTr("KONUMLAMA") }

                AxisLabel { letter: "X"; name: qsTr("İlerletme"); units: qsTr("mm · mm/s") }
                SettingCell { key: "xAltLimit" }
                SettingCell { key: "xUstLimit" }
                SettingCell { key: "xJogYavas" }
                SettingCell { key: "xJogHizli" }
                SettingCell { key: "xKonumlama" }

                AxisLabel { letter: "B"; name: qsTr("Büküm"); units: qsTr("° · °/s") }
                SettingCell { key: "bAltLimit" }
                SettingCell { key: "bUstLimit" }
                SettingCell { key: "bJogYavas" }
                SettingCell { key: "bJogHizli" }
                SettingCell { key: "bKonumlama" }

                AxisLabel { letter: "A"; name: qsTr("Rotasyon"); units: qsTr("° · °/s") }
                SettingCell { key: "aAltLimit" }
                SettingCell { key: "aUstLimit" }
                SettingCell { key: "aJogYavas" }
                SettingCell { key: "aJogHizli" }
                SettingCell { key: "aKonumlama" }

                AxisLabel { letter: "Y"; name: qsTr("Öteleme"); units: qsTr("mm · mm/s") }
                SettingCell { key: "yAltLimit" }
                SettingCell { key: "yUstLimit" }
                SettingCell { key: "yJogYavas" }
                SettingCell { key: "yJogHizli" }
                SettingCell { key: "yKonumlama" }
            }
        }

        // ---------------- Döngü ve şifre ----------------
        // İç içe yerleşim, çocukları uzadığı için kendisi de uzamak ister: boy sabit kalsın.
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                implicitHeight: 96
                radius: Theme.radius
                color: Theme.field
                border.color: Theme.panelBorder

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: qsTr("BORU ALMA KONUMU X")
                            font.pixelSize: 14
                            font.bold: true
                            color: Theme.text
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Her parça buradan başlar; boru bu konumda takılır.")
                            font.pixelSize: 13
                            color: Theme.textMuted
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }

                    SettingCell {
                        key: "boruAlmaKonumu"
                        Layout.fillWidth: false
                        Layout.preferredWidth: 130
                        unitSuffix: " mm"
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                implicitHeight: 96
                radius: Theme.radius
                color: Theme.field
                border.color: page.access.defaultPin ? Theme.active : Theme.panelBorder

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: qsTr("AYARCI ŞİFRESİ")
                            font.pixelSize: 14
                            font.bold: true
                            color: Theme.text
                        }

                        Text {
                            objectName: "pinStatus"
                            Layout.fillWidth: true
                            text: page.pinMessage.length > 0 ? page.pinMessage
                                  : page.access.defaultPin ? qsTr("Varsayılan şifre kullanılıyor: değiştirmeniz önerilir.")
                                                           : qsTr("Şifre değiştirilmiş.")
                            font.pixelSize: 13
                            font.bold: page.access.defaultPin || page.pinMessage.length > 0
                            color: page.pinMessage.length > 0 ? Theme.ok
                                   : page.access.defaultPin ? Theme.activeText : Theme.textMuted
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }

                    HmiButton {
                        objectName: "changePin"
                        implicitWidth: 150
                        implicitHeight: 52
                        padding: 6
                        font.pixelSize: 14
                        text: qsTr("ŞİFREYİ\nDEĞİŞTİR")
                        onClicked: lockBar.request("pin")
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }

    NumericKeypad {
        id: keypad

        onValueEntered: value => {
            if (page.settings.setValue(page.editKey, value))
                page.access.keepAlive()
        }
    }

    // Yeni şifre iki kez yazılır: yanlış yazılan şifreyle kilitli kalınmasın.
    NumericKeypad {
        id: pinPad

        secret: true
        note: qsTr("%1-%2 rakam. Yeni şifre iki kez yazılır.").arg(page.access.minimumPinLength)
                                                          .arg(page.access.maximumPinLength)
        secretMinimum: page.access.minimumPinLength
        secretMaximum: page.access.maximumPinLength
        onSecretEntered: text => {
            if (page.pinStep === 1) {
                page.firstPin = text
                page.pinStep = 2
                pinPad.entry = ""
                pinPad.title = qsTr("Yeni şifre (tekrar)")
            } else if (text === page.firstPin && page.access.changePin(text)) {
                page.pinStep = 0
                page.firstPin = ""
                page.pinMessage = qsTr("✓ Şifre değiştirildi.")
                pinPad.close()
            } else {
                // İki yazım aynı değil: baştan.
                page.pinStep = 1
                page.firstPin = ""
                pinPad.title = qsTr("Yeni şifre")
                pinPad.entry = ""
                pinPad.errorText = qsTr("İki şifre aynı değil, yeniden yazın")
            }
        }
        onClosed: {
            page.pinStep = 0
            page.firstPin = ""
        }
    }

    ConfirmDialog {
        id: defaultsConfirm

        title: qsTr("Bütün ayarlar varsayılana dönsün mü?")
        message: qsTr("Eksenlerin limitleri ve hızları ile boru alma konumu varsayılan değerlerine döner.")
        acceptText: qsTr("VARSAYILANA DÖN")
        acceptAccent: Theme.danger
        onAccepted: {
            if (page.settings.resetAll())
                page.access.keepAlive()
        }
    }

    // Tablo başlığı: değer sütunlarıyla aynı hizada, sağa yaslı
    component HeaderText: Text {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        horizontalAlignment: Text.AlignRight
        rightPadding: 10
        font.pixelSize: 12
        font.bold: true
        color: Theme.textMuted
    }

    // Eksenin adı ve birimleri
    component AxisLabel: Column {
        id: axisLabel

        required property string letter
        required property string name
        required property string units

        Layout.preferredWidth: 118
        spacing: 0

        Text {
            text: axisLabel.letter + "  " + axisLabel.name
            font.pixelSize: 15
            font.bold: true
            color: Theme.text
        }

        Text {
            text: axisLabel.units
            font.pixelSize: 12
            color: Theme.textMuted
        }
    }

    // Bir ayarın değeri: dokununca (şifre sorulur) tuş takımı açılır. Varsayılandan
    // farklıysa turuncu çerçeveli. Makine ayarları kilitlediyse dokunulmaz.
    component SettingCell: T.Button {
        id: cell

        required property string key
        property string unitSuffix: ""
        // Liste dışında gösterildiği için revision'a bağlı: değer ya da aralık değişince yenilenir.
        readonly property var info: page.settings.revision >= 0
                                    ? page.settings.get(page.settings.indexOf(cell.key)) : ({})
        readonly property bool modified: cell.info.modified === true

        objectName: "setting:" + cell.key
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.preferredHeight: 44
        enabled: !page.settings.locked
        opacity: enabled ? 1.0 : 0.45
        rightPadding: 10
        text: cell.info.value !== undefined ? cell.info.value.toFixed(cell.info.decimals) + cell.unitSuffix : ""
        onClicked: lockBar.request("edit:" + cell.key)

        contentItem: Text {
            text: cell.text
            font.pixelSize: 16
            font.bold: true
            color: cell.modified ? Theme.activeText : Theme.text
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        background: Rectangle {
            radius: Theme.radius
            color: cell.down ? Theme.buttonDown : Theme.field
            border.width: cell.modified ? 2 : 1
            border.color: cell.modified ? Theme.active : Theme.panelBorder
        }
    }
}
