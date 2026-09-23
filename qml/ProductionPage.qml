// Sayfa içindeki küçük bileşenler (InfoBox, ModeButton, Counter) "page" kimliğine
// güvenle erişebilsin.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// ÜRETİM sayfası: müşterinin mevcut ekranındaki düzene yakın kuruldu.
//   üstte açık program ve PROGRAM YÜKLE
//   ortada iki sekme: LİSTE (program tablosu, işlenen adım turuncu) ve SİMÜLASYON
//   (parçanın çizimi, bitmiş adımlar koyu, işlenen turuncu); sağında boru/kalıp bilgileri
//   altında ilerleme ve durum şeridi
//   en altta hidrolik kumandalar, referans arama, mod seçimi ve sayaçlar
// Döngüyü başlatan BAŞLAT butonu üst şerittedir (STOP'un yanında), çünkü makinenin
// START/STOP ikilisi her sayfadan erişilebilir olmalıdır.
Rectangle {
    id: page

    required property Machine machine
    required property BendProgram program
    required property ProgramManager manager
    required property DieLibrary dies

    // Açık program takılı kalıba uymuyorsa nedeni (Main.qml hesaplar; boş: uyuyor).
    property string toolingProblem: ""

    // Takılı kalıp kutusuna dokunuldu: KALIPLAR sayfası açılsın (Main.qml açar).
    signal diesRequested()

    // Programın kendi sorunları (makineden bağımsız)
    readonly property string programProblems: {
        const problems = []
        if (page.program.count === 0)
            problems.push(qsTr("program boş"))
        else if (page.program.remainingLength < -0.001)
            problems.push(qsTr("boru %1 mm kısa").arg((-page.program.remainingLength).toFixed(2)))
        if (page.program.invalidStepCount > 0)
            problems.push(qsTr("%1 adımda sınır dışı değer").arg(page.program.invalidStepCount))
        return problems.join(" · ")
    }

    // Makinenin kendi engeli: döngüyü neden başlatamıyor?
    readonly property string machineProblem: {
        switch (page.machine.startBlock) {
        case Machine.BlockNotHomed:
            return page.machine.state === Machine.Homing ? qsTr("referans aranıyor")
                                                         : qsTr("makine referanssız")
        case Machine.BlockPumpOff:
            // Pompa kumandası HAREKET sayfasında: operatör nereye gideceğini bilsin.
            return qsTr("hidrolik pompa çalışmıyor → HAREKET sayfası")
        case Machine.BlockClampClosed:
            return qsTr("mengene kapalı")
        case Machine.BlockColletOpen:
            return qsTr("pens açık")
        case Machine.BlockNoTooling:
            // Kalıp listesinde takılı kalıp yoksa bu zaten aşağıda yazıyor.
            return page.toolingProblem.length > 0 ? "" : qsTr("takılı kalıp makineye bildirilmemiş")
        case Machine.BlockAlarm:
            // Arızanın kendisi üstteki kırmızı şeritte yazıyor; burada ne yapılacağı yazar.
            return qsTr("arıza var → RESET")
        default:
            return ""
        }
    }

    readonly property string blockReason: {
        const reasons = []
        if (page.machineProblem.length > 0)
            reasons.push(page.machineProblem)
        if (page.toolingProblem.length > 0)
            reasons.push(page.toolingProblem)
        if (page.programProblems.length > 0)
            reasons.push(page.programProblems)
        return reasons.join(" · ")
    }

    readonly property bool ready: page.blockReason.length === 0

    // Şeritte yazan ana bilgi: makine ne yapıyor, operatörden ne bekliyor?
    // Arıza burada yazmaz: arızanın yeri üst şeritteki kırmızı alarm satırıdır (her
    // sayfada görünür). Burada yalnızca "üretime hazır değil: arıza var → RESET" çıkar.
    readonly property string cycleText: {
        if (page.machine.cycleState === Machine.CycleRunning)
            return qsTr("Üretim sürüyor")
        if (page.machine.cycleState === Machine.CycleWaiting) {
            switch (page.machine.waitReason) {
            case Machine.WaitTube:
                return qsTr("Boruyu takın, pensi kapatın ve BAŞLAT'a basın")
            case Machine.WaitStep:
                return qsTr("Adım bitti · sıradaki adım için BAŞLAT (yarı otomatik)")
            default:
                return qsTr("Parça bitti · parçayı alın, yeni boru takıp BAŞLAT'a basın")
            }
        }
        return page.ready ? qsTr("✓ Üretime hazır · BAŞLAT'a basın")
                          : qsTr("Üretime hazır değil: %1").arg(page.blockReason)
    }

    // Durumun anlamı tek yerde belirlenir; renkler buradan türer.
    //   ready: üretime hazır · busy: çalışıyor ya da operatör bekleniyor · fault: sorun var
    readonly property string statusKind: {
        if (page.machine.cycleState !== Machine.CycleStopped)
            return "busy"
        if (page.machine.hasAlarm || page.programProblems.length > 0
            || page.toolingProblem.length > 0)
            return "fault"
        return page.ready ? "ready" : "busy"
    }

    // Renk anlam taşır: yeşil hazır, turuncu devam ediyor, kırmızı sorun.
    readonly property color cycleColor: page.statusKind === "fault" ? Theme.danger
                                        : page.statusKind === "ready" ? Theme.ok : Theme.active

    // Turuncu zeminin yazı tonu daha koyu: küçük puntoda okunaklı olsun.
    readonly property color cycleTextColor: page.statusKind === "fault" ? Theme.danger
                                            : page.statusKind === "ready" ? Theme.ok : Theme.activeText

    // Parça süresi: üretim sürerken süren parçanın, dururken son parçanın süresi.
    // Makine süresi ile operatör beklemesi ayrı gösterilir: zamanın nereye gittiği görünsün.
    readonly property string partTimeText: {
        // Parça bittiğinde (yeni parça beklenirken) artık son parçanın sonucu yazar.
        const finished = page.machine.cycleState === Machine.CycleStopped
                         || (page.machine.cycleState === Machine.CycleWaiting
                             && page.machine.waitReason === Machine.WaitPart)
        if (!finished)
            return qsTr("Parça %1 s").arg(page.machine.partSeconds.toFixed(1))
        if (page.machine.lastPartSeconds <= 0)
            return ""
        return qsTr("Son parça %1 s · makine %2 s").arg(page.machine.lastPartSeconds.toFixed(1))
                                                   .arg(page.machine.lastPartMachineSeconds.toFixed(1))
    }

    // Saatlik üretim, son parçaların ortalamasından: tek parça yanıltıcı olur.
    readonly property string rateText: page.machine.averagePartSeconds > 0
                                       ? Math.round(3600 / page.machine.averagePartSeconds).toString()
                                       : "—"

    // İlerleme: kaçıncı adımdayız? Parça bitince dolu görünür.
    readonly property real progress: {
        if (page.machine.stepCount <= 0 || page.machine.cycleState === Machine.CycleStopped)
            return 0
        if (page.machine.currentStep < 0)
            return page.machine.waitReason === Machine.WaitPart ? 1 : 0
        return (page.machine.currentStep + 1) / page.machine.stepCount
    }

    // SİMÜLASYON'un renkleri için: bu adımdan öncekiler bitti. Boru beklenirken hiçbiri
    // (-1), parça bitince hepsi (adım sayısı). Yarı otomatikte bekleyen adım sıradakidir.
    readonly property int simulationStep: {
        if (page.machine.cycleState === Machine.CycleStopped)
            return -1
        if (page.machine.currentStep >= 0)
            return page.machine.currentStep
        return page.machine.waitReason === Machine.WaitPart ? page.program.count : -1
    }

    readonly property string stepText: {
        if (page.machine.cycleState === Machine.CycleStopped || page.machine.stepCount <= 0)
            return ""
        if (page.machine.currentStep < 0)
            return page.machine.waitReason === Machine.WaitPart ? qsTr("Parça tamam")
                                                                : qsTr("Hazırlanıyor")
        return qsTr("Adım %1/%2").arg(page.machine.currentStep + 1).arg(page.machine.stepCount)
    }

    // Referans arama X, A ve Y eksenlerini hareket ettirir: kilitliyken aranamaz.
    readonly property bool axesLocked: page.machine.axisX.interlock !== Axis.NoInterlock
                                       || page.machine.axisA.interlock !== Axis.NoInterlock
                                       || page.machine.axisY.interlock !== Axis.NoInterlock

    function formatMm(value: real): string {
        return value.toFixed(2) + " mm"
    }

    // 116.00 → "116": kalıp adlarındaki gibi kısa gösterim
    function shortNumber(value: real): string {
        return Number(value.toFixed(2)).toString()
    }

    radius: Theme.radius
    color: Theme.panel
    border.color: Theme.panelBorder

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        // ---------------- Üst: açık program ----------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                RowLayout {
                    spacing: 10

                    Text {
                        text: qsTr("Açık program")
                        font.pixelSize: 13
                        font.bold: true
                        color: Theme.textMuted
                    }

                    Text {
                        objectName: "productionUnsaved"
                        visible: page.program.modified
                        text: qsTr("● Kaydedilmedi")
                        font.pixelSize: 13
                        font.bold: true
                        color: Theme.activeText
                    }
                }

                Text {
                    objectName: "productionProgramName"
                    Layout.fillWidth: true
                    text: page.program.name
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                    color: Theme.text
                    elide: Text.ElideRight
                }
            }

            // Müşterinin ekranındaki "DOSYA YÜKLE" gibi: kayıtlı bir programı seçip yükler.
            HmiButton {
                objectName: "loadProgram"
                Layout.preferredWidth: 170
                Layout.preferredHeight: 48
                font.pixelSize: 15
                text: qsTr("PROGRAM YÜKLE")
                enabled: page.machine.cycleState !== Machine.CycleRunning
                onClicked: page.manager.loadProgram()
            }
        }

        // ---------------- Orta: tablo / simülasyon ve boru/kalıp bilgileri ----------------
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            // Müşterinin ekranındaki gibi iki sekme: LİSTE ve SİMÜLASYON.
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6

                ViewTabs {
                    id: productionTabs

                    Layout.fillWidth: true
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: productionTabs.currentIndex

                    // TASARIM'daki tablonun aynısı; burada yalnızca gösterir ve makinenin
                    // işlediği adımı vurgular. Satırlar daha sık: beş adım bir bakışta görünsün.
                    ProgramTable {
                        program: page.program
                        currentStep: page.machine.currentStep
                        rowHeight: 38
                        emptyText: qsTr("Program boş. TASARIM sayfasında adım ekleyin ya da program yükleyin.")
                    }

                    // Parçanın çizimi: üretim sürerken adımlar ilerledikçe renklenir.
                    PartView {
                        objectName: "partView"
                        program: page.program
                        production: page.machine.cycleState !== Machine.CycleStopped
                        progressStep: page.simulationStep
                    }
                }
            }

            // Müşterinin ekranında da bu değerler tablonun sağında duruyor.
            ColumnLayout {
                Layout.fillWidth: false
                Layout.preferredWidth: 186
                Layout.fillHeight: true
                spacing: 6

                InfoBox {
                    objectName: "infoLoadPosition"
                    caption: qsTr("BORU ALMA KONUM X")
                    value: page.formatMm(page.machine.loadPosition)
                }

                InfoBox {
                    objectName: "infoTubeLength"
                    caption: qsTr("BORU BOY")
                    value: page.formatMm(page.program.tubeLength)
                }

                InfoBox {
                    objectName: "infoDeveloped"
                    caption: qsTr("AÇINIM BOYU")
                    value: page.formatMm(page.program.developedLength)
                }

                // Müşterinin ekranındaki "AKTİF KALIP": makinede duran kalıp, yarıçapı ve
                // aldığı boru çapı, program ona uyuyor mu? Dokununca KALIPLAR açılır
                // (onların "KALIP SEÇ" butonunun karşılığı).
                Rectangle {
                    objectName: "infoDie"
                    Layout.fillWidth: true
                    implicitHeight: 76
                    radius: Theme.radius
                    color: dieTap.pressed ? Theme.buttonDown : Theme.field
                    border.width: page.toolingProblem.length > 0 ? 2 : 1
                    border.color: page.toolingProblem.length > 0 ? Theme.danger : Theme.panelBorder

                    TapHandler {
                        id: dieTap

                        onTapped: page.diesRequested()
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 10
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: qsTr("TAKILI KALIP")
                            font.pixelSize: 11
                            font.bold: true
                            color: Theme.textMuted
                        }

                        Text {
                            objectName: "infoDieName"
                            width: parent.width
                            text: page.dies.hasActive ? page.dies.activeName : qsTr("Seçilmemiş")
                            font.pixelSize: 15
                            font.bold: true
                            color: page.dies.hasActive ? Theme.text : Theme.activeText
                            elide: Text.ElideRight
                        }

                        Text {
                            objectName: "infoDieFit"
                            width: parent.width
                            text: !page.dies.hasActive
                                  ? qsTr("Seçmek için dokunun")
                                  : (page.toolingProblem.length === 0 ? "✓ " : "✗ ")
                                    + qsTr("R%1 · Ø%2 %3").arg(page.shortNumber(page.dies.activeRadius))
                                                         .arg(page.shortNumber(page.dies.activeTubeDiameter))
                                                         .arg(page.toolingProblem.length === 0 ? qsTr("uyuyor")
                                                                                              : qsTr("uymuyor"))
                            font.pixelSize: 12
                            font.bold: true
                            color: !page.dies.hasActive ? Theme.activeText
                                   : page.toolingProblem.length === 0 ? Theme.ok : Theme.danger
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "›"
                        font.pixelSize: 24
                        font.bold: true
                        color: Theme.textMuted
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
            }
        }

        // ---------------- İlerleme ve durum şeridi ----------------
        Rectangle {
            objectName: "readiness"
            Layout.fillWidth: true
            implicitHeight: 66
            radius: Theme.radius
            color: Theme.field
            border.color: Theme.panelBorder

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 8
                radius: Theme.radius
                color: page.cycleColor
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 12
                anchors.topMargin: 8
                anchors.bottomMargin: 10
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        objectName: "readinessText"
                        Layout.fillWidth: true
                        text: page.cycleText
                        font.pixelSize: 15
                        font.bold: true
                        color: page.cycleTextColor
                        elide: Text.ElideRight
                    }

                    Text {
                        objectName: "partTimeText"
                        visible: page.partTimeText.length > 0
                        text: page.partTimeText
                        font.pixelSize: 14
                        color: Theme.textMuted
                    }

                    Text {
                        objectName: "stepText"
                        visible: page.stepText.length > 0
                        text: page.stepText
                        font.pixelSize: 15
                        font.bold: true
                        color: Theme.text
                    }
                }

                // Müşterinin ekranındaki yüzde çubuğunun karşılığı.
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 10
                    radius: 5
                    color: Theme.buttonDown

                    Rectangle {
                        objectName: "progressFill"
                        width: parent.width * page.progress
                        height: parent.height
                        radius: 5
                        color: page.cycleColor

                        Behavior on width {
                            NumberAnimation { duration: 150 }
                        }
                    }
                }
            }
        }

        // ---------------- Alt şerit: hidrolik, referans, mod ve sayaçlar ----------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Boruyu takarken operatörün pense buradan ulaşması gerekir: müşterinin
            // ekranında da hidrolik kumandalar üretim sayfasındadır.
            RowLayout {
                Layout.fillWidth: false
                Layout.preferredWidth: 318
                spacing: 6

                ActuatorButton {
                    objectName: "prodClampButton"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 96
                    machine: page.machine
                    actuator: page.machine.clamp
                    title: qsTr("MENGENE")
                    onText: qsTr("KAPALI")
                    offText: qsTr("AÇIK")
                    turningOnText: qsTr("KAPANIYOR")
                    turningOffText: qsTr("AÇILIYOR")
                }

                ActuatorButton {
                    objectName: "prodMandrelButton"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 96
                    machine: page.machine
                    actuator: page.machine.mandrel
                    title: qsTr("MALAFA")
                    onText: qsTr("İLERİDE")
                    offText: qsTr("GERİDE")
                    turningOnText: qsTr("İLERİ…")
                    turningOffText: qsTr("GERİ…")
                }

                ActuatorButton {
                    objectName: "prodColletButton"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 96
                    machine: page.machine
                    actuator: page.machine.collet
                    title: qsTr("PENS")
                    onText: qsTr("KAPALI")
                    offText: qsTr("AÇIK")
                    turningOnText: qsTr("KAPANIYOR")
                    turningOffText: qsTr("AÇILIYOR")
                }
            }

            // Referans arama: eksenlerin referans durumu üst şeritteki noktalarda
            // görünür, burada yalnızca komutu var (müşterinin "HOME SIFIRLAMA"sı gibi).
            ColumnLayout {
                Layout.fillWidth: false
                Layout.preferredWidth: 134
                spacing: 4

                HmiButton {
                    objectName: "homeButton"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 72
                    font.pixelSize: 15
                    text: page.machine.state === Machine.Ready ? qsTr("TEKRAR\nREFERANS ARA")
                                                               : qsTr("REFERANS ARA\n(HOME)")
                    accent: page.machine.state === Machine.Ready ? Theme.text : Theme.active
                    enabled: page.machine.state !== Machine.Homing && !page.axesLocked
                    onClicked: page.machine.startHoming()
                }

                Text {
                    objectName: "homeHint"
                    Layout.fillWidth: true
                    text: page.axesLocked ? (page.machine.axisX.interlock !== Axis.CycleActive
                                             ? qsTr("Önce mengeneyi açın")
                                             : page.machine.cycleState === Machine.CycleRunning
                                               ? qsTr("Döngü çalışıyor") : qsTr("Döngü bekliyor · STOP"))
                          : page.machine.state === Machine.Ready ? qsTr("Sıra: B → Y → A → X")
                                                                 : qsTr("Üretimden önce gerekli")
                    font.pixelSize: 12
                    font.bold: page.axesLocked
                    color: page.axesLocked ? Theme.activeText : Theme.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            // Mod seçimi ve sayaçlar: müşterinin ekranında da yan yana duruyor.
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 300
                spacing: 6

                Text {
                    text: qsTr("MOD SEÇİMİ")
                    font.pixelSize: 12
                    font.bold: true
                    color: Theme.textMuted
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    ModeButton {
                        objectName: "modeSemi"
                        text: qsTr("YARI OTOMATİK")
                        selected: page.machine.cycleMode === Machine.SemiAutomaticCycle
                        onClicked: page.machine.cycleMode = Machine.SemiAutomaticCycle
                    }

                    ModeButton {
                        objectName: "modeAuto"
                        text: qsTr("OTOMATİK")
                        selected: page.machine.cycleMode === Machine.AutomaticCycle
                        onClicked: page.machine.cycleMode = Machine.AutomaticCycle
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Counter {
                        objectName: "partCount"
                        caption: qsTr("ÜRETİLEN ADET")
                        value: page.machine.partCount
                    }

                    HmiButton {
                        objectName: "resetPartCount"
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        font.pixelSize: 20
                        text: "↺"
                        enabled: page.machine.partCount > 0
                                 && page.machine.cycleState !== Machine.CycleRunning
                        onClicked: page.machine.resetPartCount()
                    }

                    Counter {
                        objectName: "totalCount"
                        caption: qsTr("TOPLAM ADET")
                        value: page.machine.totalCount
                    }

                    // Fabrikanın en çok baktığı sayı: bu hızla saatte kaç parça çıkar?
                    Counter {
                        objectName: "hourlyRate"
                        caption: qsTr("SAATTE (ADET)")
                        valueText: page.rateText
                    }
                }
            }
        }
    }

    // Boru ve kalıp bilgisi kutusu: üstte başlık, altta değer.
    component InfoBox: Rectangle {
        id: box

        required property string caption
        required property string value

        Layout.fillWidth: true
        implicitHeight: 46
        radius: Theme.radius
        color: Theme.field
        border.color: Theme.panelBorder

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: box.caption
                font.pixelSize: 11
                font.bold: true
                color: Theme.textMuted
                elide: Text.ElideRight
            }

            Text {
                objectName: "boxValue"
                width: parent.width
                text: box.value
                font.pixelSize: 15
                font.bold: true
                color: Theme.text
                elide: Text.ElideRight
            }
        }
    }

    // Mod seçimi butonu: seçili olan koyu dolu görünür.
    component ModeButton: HmiButton {
        property bool selected: false

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.preferredHeight: 44
        font.pixelSize: 14
        accent: Theme.navSelected
        filled: selected
        // Mod, döngünün ortasında değişmez: makine de kabul etmez.
        enabled: page.machine.cycleState !== Machine.CycleRunning
    }

    // Adet sayacı: üstte başlık, altta sayı.
    component Counter: Rectangle {
        id: counter

        required property string caption
        property int value: 0
        property string valueText: "" // sayı yerine yazı (ör. "—")

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 44
        radius: Theme.radius
        color: Theme.field
        border.color: Theme.panelBorder

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            // Dar ekranda (1024) başlık kesilmesin: önce küçülür.
            Text {
                width: parent.width
                text: counter.caption
                font.pixelSize: 11
                font.bold: true
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 9
                color: Theme.textMuted
                elide: Text.ElideRight
            }

            Text {
                objectName: "counterValue"
                width: parent.width
                text: counter.valueText.length > 0 ? counter.valueText : counter.value.toString()
                font.pixelSize: 18
                font.bold: true
                color: Theme.text
                elide: Text.ElideRight
            }
        }
    }
}
