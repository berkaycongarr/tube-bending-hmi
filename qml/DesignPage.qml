// Liste satırları bu dosyadaki "page" ve "list" kimliklerine güvenle erişebilsin.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

// TASARIM sayfası: büküm programını (reçeteyi) düzenleme.
// Solda komut listesi, sağda boru ve kalıp bilgileri ile açınım boyu doğrulaması.
// Program üretimden ayrı bir sayfada düzenlenir; üretim ekranı onu yalnızca gösterir.
Rectangle {
    id: page

    required property BendProgram program

    // Seçili satır (-1: seçim yok). Ekleme seçili satırın altına yapılır.
    property int currentRow: -1

    // Tuş takımı şu an neyi düzenliyor?
    property string editKind: ""
    property int editRow: -1
    property int editCommand: BendProgram.Feed

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

    function unitFor(command: int): string {
        return command === BendProgram.Feed ? "mm" : "°"
    }

    function formatValue(value: real, unit: string): string {
        return value.toFixed(2) + (unit === "°" ? "°" : " " + unit)
    }

    // Satırı seç ve listede görünür olmasını sağla (liste uzunsa kaydırır).
    function selectRow(row: int) {
        page.currentRow = row
        if (row >= 0)
            list.positionViewAtIndex(row, ListView.Contain)
    }

    function openKeypad(kind: string, title: string, unit: string,
                        minimum: real, maximum: real, note: string) {
        page.editKind = kind
        keypad.title = title
        keypad.unit = unit
        keypad.minimum = minimum
        keypad.maximum = maximum
        keypad.note = note
        keypad.open()
    }

    // Var olan bir adımın değerini değiştir.
    function editStep(row: int, command: int, value: real) {
        page.selectRow(row)
        page.editRow = row
        const unit = page.unitFor(command)
        page.openKeypad("step", qsTr("%1. adım · %2").arg(row + 1).arg(page.commandName(command)), unit,
                        page.program.minimumValue(command), page.program.maximumValue(command),
                        qsTr("Şu anki değer: %1").arg(page.formatValue(value, unit)))
    }

    // Seçili satırın altına (seçim yoksa sona) yeni adım ekle: önce değeri sor.
    function addStep(command: int) {
        page.editCommand = command
        page.openKeypad("insert", qsTr("Yeni adım · %1").arg(page.commandName(command)),
                        page.unitFor(command),
                        page.program.minimumValue(command), page.program.maximumValue(command),
                        page.currentRow >= 0 ? qsTr("%1. adımın altına eklenecek").arg(page.currentRow + 1)
                                             : qsTr("Programın sonuna eklenecek"))
    }

    function editTube(kind: string, title: string, minimum: real, maximum: real, value: real) {
        page.openKeypad(kind, title, "mm", minimum, maximum,
                        qsTr("Şu anki değer: %1").arg(page.formatValue(value, "mm")))
    }

    // Tuş takımında TAMAM'a basıldı: değeri doğru yere yaz.
    function applyValue(value: real) {
        switch (page.editKind) {
        case "step":
            page.program.setValue(page.editRow, value)
            break
        case "insert": {
            const row = page.currentRow >= 0 ? page.currentRow + 1 : page.program.count
            if (page.program.insertStep(row, page.editCommand, value))
                page.selectRow(row)
            break
        }
        case "tubeLength":
            page.program.tubeLength = value
            break
        case "tubeDiameter":
            page.program.tubeDiameter = value
            break
        case "dieRadius":
            page.program.dieRadius = value
            break
        }
    }

    radius: Theme.radius
    color: Theme.panel
    border.color: Theme.panelBorder

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // ---------------- Sol: program tablosu ----------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: qsTr("Program")
                    font.pixelSize: Theme.fontNormal
                    color: Theme.textMuted
                }

                Text {
                    Layout.fillWidth: true
                    text: page.program.name
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                    color: Theme.text
                    elide: Text.ElideRight
                }

                Text {
                    text: qsTr("%1 adım").arg(page.program.count)
                    font.pixelSize: Theme.fontNormal
                    color: Theme.textMuted
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                // Tablo: başlık ve satırlar
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 6

                    // Sütunlar müşterinin mevcut ekranındaki gibi. Birimler başlıkta
                    // yazılı olduğu için hücrelerde yalnızca sayı görünür.
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
                            model: page.program

                            // Bir satır: numara, komut ve değer. Değer yalnızca komutun
                            // sütununda görünür; değere dokununca tuş takımı açılır.
                            delegate: Rectangle {
                                id: stepRow

                                required property int index
                                required property int command
                                required property real value
                                required property bool valid

                                readonly property bool selected: page.currentRow === stepRow.index

                                objectName: "step" + stepRow.index
                                width: list.width
                                height: 48
                                radius: Theme.radius
                                color: stepRow.selected ? Theme.selection : Theme.field
                                border.width: stepRow.selected ? 2 : 1
                                border.color: stepRow.selected ? Theme.navSelected : Theme.panelBorder

                                TapHandler {
                                    onTapped: page.selectRow(stepRow.index)
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
                                        text: page.commandName(stepRow.command)
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

                                            T.Button {
                                                id: valueButton

                                                objectName: "value" + stepRow.index
                                                anchors.fill: parent
                                                anchors.topMargin: 5
                                                anchors.bottomMargin: 5
                                                visible: cell.index === stepRow.command
                                                rightPadding: 10
                                                text: stepRow.value.toFixed(2)
                                                onClicked: page.editStep(stepRow.index, stepRow.command, stepRow.value)

                                                contentItem: Text {
                                                    text: valueButton.text
                                                    font.pixelSize: Theme.fontNormal
                                                    font.bold: true
                                                    color: stepRow.valid ? Theme.text : Theme.danger
                                                    horizontalAlignment: Text.AlignRight
                                                    verticalAlignment: Text.AlignVCenter
                                                }

                                                background: Rectangle {
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
                        // Satırların üstüne binmesin diye listeyle butonlar arasındaki boşlukta.
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
                            visible: page.program.count === 0
                            text: qsTr("Program boş. Aşağıdan adım ekleyin.")
                            font.pixelSize: Theme.fontNormal
                            color: Theme.textMuted
                        }
                    }
                }

                // Satır düzenleme: taşıma yukarıda, silme ayrı ve aşağıda
                // (yanlışlıkla silmeyi zorlaştırmak için).
                ColumnLayout {
                    Layout.fillWidth: false
                    Layout.fillHeight: true
                    Layout.topMargin: 50 // başlık (44) + aralık (6): ilk satırla aynı hizada başlar
                    spacing: 8

                    HmiButton {
                        objectName: "moveUp"
                        implicitWidth: 56
                        implicitHeight: 56
                        text: "▲"
                        enabled: page.currentRow > 0
                        onClicked: {
                            const row = page.currentRow
                            if (page.program.moveStep(row, row - 1))
                                page.selectRow(row - 1)
                        }
                    }

                    HmiButton {
                        objectName: "moveDown"
                        implicitWidth: 56
                        implicitHeight: 56
                        text: "▼"
                        enabled: page.currentRow >= 0 && page.currentRow < page.program.count - 1
                        onClicked: {
                            const row = page.currentRow
                            if (page.program.moveStep(row, row + 1))
                                page.selectRow(row + 1)
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    HmiButton {
                        objectName: "removeStep"
                        implicitWidth: 56
                        implicitHeight: 56
                        padding: 4
                        font.pixelSize: 16
                        text: qsTr("SİL")
                        accent: Theme.danger
                        enabled: page.currentRow >= 0
                        onClicked: {
                            const row = page.currentRow
                            page.program.removeStep(row)
                            page.selectRow(Math.min(row, page.program.count - 1))
                        }
                    }
                }
            }

            // Adım ekleme: seçili satırın altına, seçim yoksa sona
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                HmiButton {
                    objectName: "addFeed"
                    Layout.fillWidth: true
                    implicitHeight: 56
                    font.pixelSize: 16
                    text: qsTr("+ İLERLE")
                    onClicked: page.addStep(BendProgram.Feed)
                }

                HmiButton {
                    objectName: "addBend"
                    Layout.fillWidth: true
                    implicitHeight: 56
                    font.pixelSize: 16
                    text: qsTr("+ BÜK")
                    onClicked: page.addStep(BendProgram.Bend)
                }

                HmiButton {
                    objectName: "addRotate"
                    Layout.fillWidth: true
                    implicitHeight: 56
                    font.pixelSize: 16
                    text: qsTr("+ ROTASYON")
                    onClicked: page.addStep(BendProgram.Rotate)
                }
            }
        }

        // ---------------- Sağ: boru, kalıp ve açınım boyu ----------------
        // İç içe yerleşimler varsayılan olarak genişler; bu sütun sabit genişlikte kalsın.
        ColumnLayout {
            Layout.fillWidth: false
            Layout.preferredWidth: 230
            Layout.fillHeight: true
            spacing: 10

            Text {
                text: qsTr("Boru ve kalıp")
                font.pixelSize: Theme.fontNormal
                font.bold: true
                color: Theme.text
            }

            ValueField {
                objectName: "tubeLength"
                Layout.fillWidth: true
                caption: qsTr("Boru boyu")
                text: page.formatValue(page.program.tubeLength, "mm")
                onClicked: page.editTube("tubeLength", qsTr("Boru boyu"), 10, 6000, page.program.tubeLength)
            }

            ValueField {
                objectName: "tubeDiameter"
                Layout.fillWidth: true
                caption: qsTr("Boru çapı")
                text: page.formatValue(page.program.tubeDiameter, "mm")
                onClicked: page.editTube("tubeDiameter", qsTr("Boru çapı"), 4, 120, page.program.tubeDiameter)
            }

            ValueField {
                objectName: "dieRadius"
                Layout.fillWidth: true
                caption: qsTr("Kalıp yarıçapı (R)")
                text: page.formatValue(page.program.dieRadius, "mm")
                onClicked: page.editTube("dieRadius", qsTr("Kalıp yarıçapı (R)"), 5, 500, page.program.dieRadius)
            }

            // Açınım boyu: programın ihtiyaç duyduğu boru boyu
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 6
                implicitHeight: summary.implicitHeight + 24
                radius: Theme.radius
                color: Theme.field
                border.width: page.program.valid ? 1 : 2
                border.color: page.program.valid ? Theme.panelBorder : Theme.danger

                ColumnLayout {
                    id: summary

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 4

                    Text {
                        text: qsTr("Açınım boyu")
                        font.pixelSize: 13
                        font.bold: true
                        color: Theme.textMuted
                    }

                    Text {
                        objectName: "developedLength"
                        text: page.formatValue(page.program.developedLength, "mm")
                        font.pixelSize: Theme.fontTitle
                        font.bold: true
                        color: Theme.text
                    }

                    Text {
                        objectName: "remainingText"
                        Layout.fillWidth: true
                        text: page.program.count === 0
                              ? qsTr("Program boş")
                              : page.program.remainingLength >= 0
                                ? qsTr("Artan: %1 ✓").arg(page.formatValue(page.program.remainingLength, "mm"))
                                : qsTr("Boru %1 kısa").arg(page.formatValue(-page.program.remainingLength, "mm"))
                        font.pixelSize: Theme.fontNormal
                        font.bold: true
                        color: page.program.count > 0 && page.program.remainingLength >= 0 ? Theme.ok
                                                                                           : Theme.danger
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        objectName: "invalidText"
                        Layout.fillWidth: true
                        visible: page.program.invalidStepCount > 0
                        text: qsTr("%1 adımda sınır dışı değer").arg(page.program.invalidStepCount)
                        font.pixelSize: Theme.fontSmall
                        font.bold: true
                        color: Theme.danger
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Açınım boyu = düz parçalar + büküm yayları. "
                           + "Bir yayın boyu: kalıp yarıçapı × büküm açısı (radyan).")
                font.pixelSize: 13
                color: Theme.textMuted
                wrapMode: Text.WordWrap
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }

    NumericKeypad {
        id: keypad

        onValueEntered: value => page.applyValue(value)
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
