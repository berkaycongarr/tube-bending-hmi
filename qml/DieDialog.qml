// İçerideki küçük bileşenler (CheckTile) "dialog" kimliğine güvenle erişebilsin.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

// Kalıp penceresi: yeni kalıp ekleme ya da var olanı düzenleme.
// Açıklama bilgisayar klavyesiyle, sayılar tuş takımıyla girilir. KAYDET'e basınca
// kalıp hemen dosyaya yazılır; yazılamazsa pencere açık kalır ve nedeni görünür.
T.Popup {
    id: dialog

    required property DieLibrary dies

    // Düzenlenen kalıbın satırı (-1: yeni kalıp)
    property int editRow: -1

    // Girilen değerler (NaN: henüz girilmedi)
    property real radius: NaN
    property real tubeDiameter: NaN
    property bool mandrel: false
    property bool feedDuringBend: false

    // Kaydedilen kalıbın adı (sayfa seçimi bu ada taşır)
    signal saved(string name)

    readonly property string nameError: dialog.dies.nameError(input.text, dialog.editRow)
    readonly property bool valuesSet: !isNaN(dialog.radius) && !isNaN(dialog.tubeDiameter)
    readonly property bool canSave: dialog.nameError.length === 0 && dialog.valuesSet

    // Kaydetme denendi ve başarısız oldu mu? (Dosyaya yazılamadıysa neden gösterilir.)
    property bool saveFailed: false

    function openNew() {
        dialog.editRow = -1
        input.text = ""
        dialog.radius = NaN
        dialog.tubeDiameter = NaN
        dialog.mandrel = false
        dialog.feedDuringBend = false
        dialog.open()
    }

    function openEdit(row: int) {
        const die = dialog.dies.get(row)
        dialog.editRow = row
        input.text = die.name
        dialog.radius = die.radius
        dialog.tubeDiameter = die.tubeDiameter
        dialog.mandrel = die.mandrel
        dialog.feedDuringBend = die.feedDuringBend
        dialog.open()
    }

    function formatMm(value: real): string {
        return isNaN(value) ? qsTr("— girilmedi") : value.toFixed(2) + " mm"
    }

    function save() {
        if (!dialog.canSave)
            return
        const name = input.text.trim()
        const ok = dialog.editRow < 0
                   ? dialog.dies.add(name, dialog.radius, dialog.tubeDiameter,
                                     dialog.mandrel, dialog.feedDuringBend)
                   : dialog.dies.update(dialog.editRow, name, dialog.radius, dialog.tubeDiameter,
                                        dialog.mandrel, dialog.feedDuringBend)
        if (!ok) {
            dialog.saveFailed = true
            return
        }
        dialog.close()
        dialog.saved(name)
    }

    // Tuş takımı hangi değeri soruyor?
    property string editKind: ""

    function editValue(kind: string, title: string, minimum: real, maximum: real, value: real) {
        dialog.editKind = kind
        keypad.title = title
        keypad.unit = "mm"
        keypad.minimum = minimum
        keypad.maximum = maximum
        keypad.note = isNaN(value) ? "" : qsTr("Şu anki değer: %1").arg(dialog.formatMm(value))
        keypad.open()
    }

    onAboutToShow: dialog.saveFailed = false
    onOpened: {
        input.selectAll()
        input.forceActiveFocus()
    }

    // Şablon (Templates) popup boyutunu kendisi hesaplamaz: içeriğe göre biz veririz.
    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    parent: T.Overlay.overlay
    anchors.centerIn: parent
    modal: true
    focus: true
    padding: 24
    closePolicy: T.Popup.CloseOnEscape

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

        Text {
            objectName: "dieDialogTitle"
            text: dialog.editRow < 0 ? qsTr("Yeni kalıp") : qsTr("Kalıbı düzenle")
            font.pixelSize: Theme.fontTitle
            font.bold: true
            color: Theme.text
        }

        Text {
            text: qsTr("Açıklama (ör. 25X50XR116)")
            font.pixelSize: Theme.fontSmall
            font.bold: true
            color: Theme.textMuted
        }

        Rectangle {
            Layout.preferredWidth: 500
            implicitHeight: 52
            radius: Theme.radius
            color: Theme.field
            border.width: 2
            border.color: dialog.nameError.length > 0 && input.text.length > 0 ? Theme.danger
                          : input.activeFocus ? Theme.navSelected : Theme.panelBorder

            TextInput {
                id: input

                objectName: "dieName"
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: 22
                font.bold: true
                color: Theme.text
                selectionColor: Theme.navSelected
                selectedTextColor: "white"
                maximumLength: dialog.dies.maxNameLength
                selectByMouse: true
                clip: true

                Keys.onReturnPressed: dialog.save()
                Keys.onEnterPressed: dialog.save()
            }
        }

        Text {
            objectName: "dieNameError"
            Layout.preferredWidth: 500
            text: dialog.nameError.length > 0 && input.text.length > 0
                  ? dialog.nameError : qsTr("Bilgisayar klavyesiyle yazın.")
            font.pixelSize: Theme.fontSmall
            font.bold: dialog.nameError.length > 0 && input.text.length > 0
            color: dialog.nameError.length > 0 && input.text.length > 0 ? Theme.danger : Theme.textMuted
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.preferredWidth: 500
            spacing: 10

            ValueField {
                objectName: "dieRadius"
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                caption: qsTr("KALIP RADIUS")
                text: dialog.formatMm(dialog.radius)
                onClicked: dialog.editValue("radius", qsTr("Kalıp yarıçapı (boru ekseninde)"),
                                            dialog.dies.minRadius, dialog.dies.maxRadius, dialog.radius)
            }

            ValueField {
                objectName: "dieDiameter"
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                caption: qsTr("BORU ÇAPI")
                text: dialog.formatMm(dialog.tubeDiameter)
                onClicked: dialog.editValue("diameter", qsTr("Boru çapı"),
                                            dialog.dies.minDiameter, dialog.dies.maxDiameter,
                                            dialog.tubeDiameter)
            }
        }

        RowLayout {
            Layout.preferredWidth: 500
            spacing: 10

            // "checked" bağlı kalsın diye buton kendisi değişmez (checkable değil):
            // tıklama değeri değiştirir, görünüm değere bakar.
            CheckTile {
                objectName: "dieMandrel"
                text: qsTr("MALAFALI BÜK")
                checked: dialog.mandrel
                onClicked: dialog.mandrel = !dialog.mandrel
            }

            CheckTile {
                objectName: "dieFeed"
                text: qsTr("BÜKÜMDE İLERLE")
                checked: dialog.feedDuringBend
                onClicked: dialog.feedDuringBend = !dialog.feedDuringBend
            }
        }

        Text {
            Layout.preferredWidth: 500
            text: qsTr("Malafalı büküm: bükülen yerde borunun içine malafa girer, boru ezilmez. "
                       + "Bükümde ilerle: büküm sırasında araba boruyu arkadan iter.")
            font.pixelSize: 13
            color: Theme.textMuted
            wrapMode: Text.WordWrap
        }

        // Dosyaya yazılamadıysa nedeni
        Text {
            objectName: "dieSaveError"
            Layout.preferredWidth: 500
            visible: dialog.saveFailed && dialog.dies.lastError.length > 0
            text: dialog.dies.lastError
            font.pixelSize: Theme.fontSmall
            font.bold: true
            color: Theme.danger
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.topMargin: 6
            Layout.alignment: Qt.AlignRight
            spacing: 8

            HmiButton {
                objectName: "dieCancel"
                implicitWidth: 140
                implicitHeight: 56
                font.pixelSize: 16
                text: qsTr("İPTAL")
                focusPolicy: Qt.NoFocus
                onClicked: dialog.close()
            }

            HmiButton {
                objectName: "dieSave"
                implicitWidth: 160
                implicitHeight: 56
                font.pixelSize: 16
                text: qsTr("KAYDET")
                accent: Theme.ok
                filled: true
                enabled: dialog.canSave
                focusPolicy: Qt.NoFocus
                onClicked: dialog.save()
            }
        }

        NumericKeypad {
            id: keypad

            onValueEntered: value => {
                if (dialog.editKind === "radius")
                    dialog.radius = value
                else
                    dialog.tubeDiameter = value
            }
        }
    }

    // İşaretlenebilir kutu: müşterinin ekranındaki kutucukların dokunmatik karşılığı.
    component CheckTile: T.Button {
        id: tile

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 52
        focusPolicy: Qt.NoFocus
        leftPadding: 12
        rightPadding: 12

        contentItem: RowLayout {
            spacing: 10

            Rectangle {
                implicitWidth: 26
                implicitHeight: 26
                radius: 4
                color: tile.checked ? Theme.navSelected : Theme.field
                border.width: 2
                border.color: tile.checked ? Theme.navSelected : Theme.idle

                Text {
                    anchors.centerIn: parent
                    visible: tile.checked
                    text: "✓"
                    font.pixelSize: 18
                    font.bold: true
                    color: "white"
                }
            }

            Text {
                Layout.fillWidth: true
                text: tile.text
                font.pixelSize: 15
                font.bold: true
                color: Theme.text
                elide: Text.ElideRight
            }
        }

        background: Rectangle {
            radius: Theme.radius
            color: tile.down ? Theme.buttonDown : Theme.buttonFace
            border.width: tile.checked ? 2 : 1
            border.color: tile.checked ? Theme.navSelected : Theme.panelBorder
        }
    }
}
