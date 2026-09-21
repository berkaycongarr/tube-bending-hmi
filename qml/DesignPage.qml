import QtQuick
import QtQuick.Layouts

// TASARIM sayfası: büküm programını (reçeteyi) düzenleme.
// Solda iki sekme: LİSTE (komut listesi) ve SİMÜLASYON (parçanın çizimi, seçili adım
// mavi); sağda boru ve kalıp bilgileri ile açınım boyu doğrulaması.
// Program üretimden ayrı bir sayfada düzenlenir; üretim ekranı onu yalnızca gösterir.
Rectangle {
    id: page

    required property BendProgram program

    // Program dosya işlemleri (kaydet, programlar penceresi); Main.qml'de oluşturulur.
    required property ProgramManager manager

    // Kalıp kütüphanesi: program takılı kalıba uyuyor mu diye bakmak için.
    required property DieLibrary dies

    // Program takılı kalıba uymuyorsa nedeni (Main.qml hesaplar; boş: uyuyor).
    property string toolingProblem: ""

    // Takılı kalıp var ama program ona uymuyor: tek dokunuşla uydurulabilir.
    readonly property bool canFitToDie: page.dies.hasActive && page.toolingProblem.length > 0

    // Seçili satır (-1: seçim yok). Ekleme seçili satırın altına yapılır.
    property int currentRow: -1

    // Başka bir program açılınca (ya da yeni program başlayınca) seçim sıfırlanır.
    Connections {
        target: page.program

        function onModelReset() {
            page.currentRow = -1
        }
    }

    // Tuş takımı şu an neyi düzenliyor?
    property string editKind: ""
    property int editRow: -1
    property int editCommand: BendProgram.Feed

    function unitFor(command: int): string {
        return command === BendProgram.Feed ? "mm" : "°"
    }

    function formatValue(value: real, unit: string): string {
        return value.toFixed(2) + (unit === "°" ? "°" : " " + unit)
    }

    // Satırı seç ve listede görünür olmasını sağla (liste uzunsa kaydırır).
    function selectRow(row: int) {
        page.currentRow = row
        table.showRow(row)
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
        page.openKeypad("step", qsTr("%1. adım · %2").arg(row + 1).arg(table.commandName(command)), unit,
                        page.program.minimumValue(command), page.program.maximumValue(command),
                        qsTr("Şu anki değer: %1").arg(page.formatValue(value, unit)))
    }

    // Seçili satırın altına (seçim yoksa sona) yeni adım ekle: önce değeri sor.
    function addStep(command: int) {
        page.editCommand = command
        page.openKeypad("insert", qsTr("Yeni adım · %1").arg(table.commandName(command)),
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

                // Ad sığdığı kadar yer kaplar; yer darsa sonu "…" ile kısalır.
                Text {
                    objectName: "programName"
                    Layout.fillWidth: true
                    Layout.maximumWidth: implicitWidth
                    text: page.program.name
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                    color: Theme.text
                    elide: Text.ElideRight
                }

                // Son kayıttan beri değişiklik var mı?
                Text {
                    objectName: "unsavedMark"
                    visible: page.program.modified
                    text: qsTr("● Kaydedilmedi")
                    font.pixelSize: Theme.fontSmall
                    font.bold: true
                    color: Theme.activeText
                }

                Text {
                    objectName: "savedMark"
                    visible: page.manager.justSaved && !page.program.modified
                    text: qsTr("✓ Kaydedildi")
                    font.pixelSize: Theme.fontSmall
                    font.bold: true
                    color: Theme.ok
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: qsTr("%1 adım").arg(page.program.count)
                    font.pixelSize: Theme.fontNormal
                    color: Theme.textMuted
                }
            }

            // Müşterinin ekranındaki gibi iki sekme. SİMÜLASYON'da da adım eklenebilir:
            // parça, eklenen her adımla çizimde büyür.
            ViewTabs {
                id: designTabs

                Layout.fillWidth: true
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: designTabs.currentIndex

                RowLayout {
                    spacing: 8

                    // Tablo: başlık ve satırlar (ÜRETİM sayfasıyla ortak bileşen)
                    ProgramTable {
                        id: table

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        program: page.program
                        editable: true
                        selectedRow: page.currentRow
                        emptyText: qsTr("Program boş. Aşağıdan adım ekleyin.")
                        onRowTapped: row => page.selectRow(row)
                        onValueClicked: (row, command, value) => page.editStep(row, command, value)
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

                // Parçanın çizimi; seçili adım mavi görünür (ekleme onun altına yapılır).
                PartView {
                    objectName: "partView"
                    program: page.program
                    highlightStep: page.currentRow
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

            // Program dosyası: kaydet ve programlar penceresi
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                HmiButton {
                    objectName: "saveProgram"
                    Layout.preferredWidth: 90
                    implicitHeight: 48
                    padding: 6
                    font.pixelSize: 14
                    text: qsTr("KAYDET")
                    accent: Theme.ok
                    enabled: page.manager.canSave
                    onClicked: page.manager.save()
                }

                HmiButton {
                    objectName: "showPrograms"
                    Layout.fillWidth: true
                    implicitHeight: 48
                    padding: 6
                    font.pixelSize: 14
                    text: qsTr("PROGRAMLAR")
                    onClicked: page.manager.showPrograms()
                }
            }

            Text {
                text: qsTr("Boru ve kalıp")
                font.pixelSize: Theme.fontNormal
                font.bold: true
                color: Theme.text
            }

            ValueField {
                objectName: "tubeLength"
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                topPadding: 6
                bottomPadding: 6
                caption: qsTr("Boru boyu")
                text: page.formatValue(page.program.tubeLength, "mm")
                onClicked: page.editTube("tubeLength", qsTr("Boru boyu"), 10, 6000, page.program.tubeLength)
            }

            ValueField {
                objectName: "tubeDiameter"
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                topPadding: 6
                bottomPadding: 6
                caption: qsTr("Boru çapı")
                text: page.formatValue(page.program.tubeDiameter, "mm")
                onClicked: page.editTube("tubeDiameter", qsTr("Boru çapı"), 4, 120, page.program.tubeDiameter)
            }

            ValueField {
                objectName: "dieRadius"
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                topPadding: 6
                bottomPadding: 6
                caption: qsTr("Kalıp yarıçapı (R)")
                text: page.formatValue(page.program.dieRadius, "mm")
                onClicked: page.editTube("dieRadius", qsTr("Kalıp yarıçapı (R)"), 5, 500, page.program.dieRadius)
            }

            // Program makinede duran kalıba uyuyor mu? Program başka bir kalıp için
            // yazılmışsa üretimde BAŞLAT'a basılamaz.
            Text {
                objectName: "designDieStatus"
                Layout.fillWidth: true
                text: !page.dies.hasActive ? qsTr("Takılı kalıp seçilmemiş (KALIPLAR)")
                      : page.toolingProblem.length === 0
                        ? qsTr("✓ Takılı kalıba uyuyor (%1)").arg(page.dies.activeName)
                        : qsTr("✗ Takılı kalıp %1 (R%2, Ø%3): program ona uymuyor")
                              .arg(page.dies.activeName)
                              .arg(Number(page.dies.activeRadius.toFixed(2)))
                              .arg(Number(page.dies.activeTubeDiameter.toFixed(2)))
                font.pixelSize: 13
                font.bold: true
                color: !page.dies.hasActive ? Theme.activeText
                       : page.toolingProblem.length === 0 ? Theme.ok : Theme.danger
                wrapMode: Text.WordWrap
            }

            // Programın boru çapını ve kalıp yarıçapını takılı kalıbınkiyle değiştirir.
            // Açınım boyu yeni yarıçapla yeniden hesaplanır; program "değişti" olur.
            HmiButton {
                objectName: "fitToDie"
                Layout.fillWidth: true
                visible: page.canFitToDie
                implicitHeight: 44
                padding: 6
                font.pixelSize: 14
                text: qsTr("TAKILI KALIBA UYDUR")
                onClicked: {
                    page.program.tubeDiameter = page.dies.activeTubeDiameter
                    page.program.dieRadius = page.dies.activeRadius
                }
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

            // Uydurma butonu görünürken bu açıklama gizlenir: sütun dar ekrana da sığsın.
            Text {
                Layout.fillWidth: true
                visible: !page.canFitToDie
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
}
