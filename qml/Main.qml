import QtQuick
import QtQuick.Layouts

// Ana ekran: üstte durum, eksen konumları, BAŞLAT ve STOP; solda menü; ortada
// seçili sayfa; altta çalışma modu ve saat. Üst şerit her sayfada görünür kalır.
Window {
    id: root

    // main.cpp tarafından verilen makine nesnesi (demoda SimMachine).
    required property Machine machine

    // main.cpp tarafından verilen büküm programı (reçete).
    required property BendProgram program

    // main.cpp tarafından verilen program deposu (Belgeler\BoruBukme\Programlar).
    required property ProgramStore store

    // main.cpp tarafından verilen kalıp kütüphanesi (Belgeler\BoruBukme\kaliplar.json).
    required property DieLibrary dies

    // main.cpp tarafından verilen ayarcı şifresi denetimi (ayar sayfaları için).
    required property AccessControl access

    // Seçili sayfa: 0 = Üretim, 1 = Tasarım, 2 = Kalıplar, 3 = Hareket, 4 = Ayarlar,
    // 5 = Zamanlar, 6 = IO Test (sıra müşterinin ekranındaki menüyle aynı)
    property int currentPage: 0

    // Kapanış onaylandı mı? Kaydedilmemiş değişiklik varsa pencere hemen kapanmaz,
    // önce KAYDET / KAYDETME / İPTAL diye sorulur.
    property bool exitConfirmed: false

    onClosing: close => {
        if (root.program.modified && !root.exitConfirmed) {
            close.accepted = false
            programManager.requestClose()
        }
    }

    width: 1280
    height: 760
    minimumWidth: 1024
    minimumHeight: 720
    visible: true
    title: qsTr("Boru Bükme Makinesi")
    color: Theme.background

    // Şu an referans arayan eksen (yoksa null). Sıra, referans arama sırasıyla aynı.
    readonly property Axis homingAxis: machine.axisB.homing ? machine.axisB
                                     : machine.axisY.homing ? machine.axisY
                                     : machine.axisA.homing ? machine.axisA
                                     : machine.axisX.homing ? machine.axisX
                                     : null

    // Üst şeritteki durum kutusu her sayfada görünür: makinenin o an ne yaptığını söyler.
    // Sırayla: üretim sürüyor mu, operatör mü bekleniyor, referans mı aranıyor, hazır mı?
    // (Arıza varken bu kutunun yerini kırmızı arıza şeridi alır: arızanın yeri orasıdır.)
    readonly property string stateText: {
        if (machine.cycleState === Machine.CycleRunning)
            return qsTr("ÜRETİMDE")
        if (machine.cycleState === Machine.CycleWaiting) {
            switch (machine.waitReason) {
            case Machine.WaitTube:
                return qsTr("BORU BEKLENİYOR")
            case Machine.WaitStep:
                return qsTr("ADIM BEKLENİYOR")
            default:
                return qsTr("PARÇA BİTTİ")
            }
        }
        switch (machine.state) {
        case Machine.Homing:
            return qsTr("REFERANS ARANIYOR")
        case Machine.Ready:
            return qsTr("HAZIR")
        default:
            return qsTr("REFERANSSIZ")
        }
    }

    readonly property string stateHint: {
        if (machine.cycleState === Machine.CycleRunning) {
            return machine.currentStep >= 0 && machine.stepCount > 0
                   ? qsTr("Adım %1/%2").arg(machine.currentStep + 1).arg(machine.stepCount)
                   : qsTr("Parça başlıyor")
        }
        if (machine.cycleState === Machine.CycleWaiting) {
            switch (machine.waitReason) {
            case Machine.WaitTube:
                return qsTr("Boruyu takın, pensi kapatın, BAŞLAT")
            case Machine.WaitStep:
                return qsTr("Sıradaki adım için BAŞLAT")
            default:
                return qsTr("Parçayı alın, yeni boru takın")
            }
        }
        switch (machine.state) {
        case Machine.Homing:
            return homingAxis ? qsTr("%1 ekseni referans noktasına gidiyor").arg(homingAxis.name) : ""
        case Machine.Ready:
            return qsTr("Tüm eksenler referanslı")
        default:
            return qsTr("Üretimden önce referans aranmalı")
        }
    }

    readonly property color stateColor: {
        if (machine.cycleState === Machine.CycleRunning)
            return Theme.ok
        if (machine.cycleState === Machine.CycleWaiting)
            return Theme.active
        switch (machine.state) {
        case Machine.Homing:
            return Theme.active
        case Machine.Ready:
            return Theme.ok
        default:
            return Theme.idle
        }
    }

    // Açık program takılı kalıba uyuyor mu? Uymuyorsa nedeni (boş: uyuyor).
    // Makine de BAŞLAT'ta kendisi karşılaştırır; burası operatöre nedenini gösterir.
    readonly property string toolingProblem: {
        if (!root.dies.hasActive)
            return qsTr("takılı kalıp seçilmemiş")
        const radiusFits = Math.abs(root.program.dieRadius - root.dies.activeRadius) <= 0.005
        const diameterFits = Math.abs(root.program.tubeDiameter - root.dies.activeTubeDiameter) <= 0.005
        if (radiusFits && diameterFits)
            return ""
        return qsTr("takılı kalıp programa uymuyor (program R%1 Ø%2, kalıp R%3 Ø%4)")
                   .arg(root.shortNumber(root.program.dieRadius))
                   .arg(root.shortNumber(root.program.tubeDiameter))
                   .arg(root.shortNumber(root.dies.activeRadius))
                   .arg(root.shortNumber(root.dies.activeTubeDiameter))
    }

    // 116.00 → "116", 116.50 → "116.5": kısa gösterim (kalıp adlarındaki gibi)
    function shortNumber(value: real): string {
        return Number(value.toFixed(2)).toString()
    }

    // Üretim döngüsü başlatılabilir mi? Makinenin kendi denetimine (referans,
    // pompa, mengene, takılı kalıp) programın geçerliliği ve kalıba uyması da
    // eklenir. Makine yine de kendisi bakar: buton yanlışlıkla açık kalsa bile
    // döngü başlamaz.
    readonly property bool canStart: machine.startBlock === Machine.StartReady && program.valid
                                     && toolingProblem.length === 0

    // Bekleyen bir döngü varsa START "devam et" demektir.
    readonly property bool resuming: machine.cycleState === Machine.CycleWaiting

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // Üst şerit: durum, eksen konumları, BAŞLAT ve STOP. Müşterinin ekranında
        // da bu ikili sağ üst köşede duruyor; her sayfadan erişilir.
        // Dar ekranda (1024 px) kutular daralır: eksenler 172'den 127 px'e (konum
        // yazısı da sığana kadar küçülür), butonlar 124'ten 106 px'e; durum
        // kutusu en az 210 px kalır ki "REFERANS ARANIYOR" kesilmesin.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 72

            RowLayout {
                id: topStrip

                anchors.fill: parent
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 210
                    Layout.preferredHeight: 72
                    radius: Theme.radius
                    color: Theme.panel
                    border.color: Theme.panelBorder

                    // Soldaki renkli şerit makinenin durumunu gösterir.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 8
                        radius: Theme.radius
                        color: root.stateColor
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 24
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        // Uzun durum yazısı dar alanda önce küçülür, yine sığmazsa kısaltılır.
                        Text {
                            objectName: "stateText"
                            width: parent.width
                            text: root.stateText
                            font.pixelSize: Theme.fontTitle
                            font.bold: true
                            fontSizeMode: Text.HorizontalFit
                            minimumPixelSize: 14
                            color: Theme.text
                            elide: Text.ElideRight
                        }

                        Text {
                            objectName: "stateHint"
                            width: parent.width
                            text: root.stateHint
                            font.pixelSize: Theme.fontSmall
                            color: Theme.textMuted
                            elide: Text.ElideRight
                        }
                    }
                }

                AxisDisplay {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 127
                    Layout.maximumWidth: 172
                    axis: root.machine.axisX
                    title: qsTr("İlerletme")
                }

                AxisDisplay {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 127
                    Layout.maximumWidth: 172
                    axis: root.machine.axisB
                    title: qsTr("Büküm")
                }

                AxisDisplay {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 127
                    Layout.maximumWidth: 172
                    axis: root.machine.axisA
                    title: qsTr("Rotasyon")
                }

                AxisDisplay {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 127
                    Layout.maximumWidth: 172
                    axis: root.machine.axisY
                    title: qsTr("Öteleme")
                }

                // Üretim döngüsünü başlatır ya da bekleyen döngüye devam ettirir.
                // Tarifi ekran gönderir, adımları makine yürütür.
                HmiButton {
                    id: startButton

                    objectName: "startButton"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 106
                    Layout.maximumWidth: 124
                    Layout.preferredHeight: 72
                    font.pixelSize: 15
                    text: root.resuming ? qsTr("▶ DEVAM") : qsTr("▶ BAŞLAT")
                    accent: Theme.ok
                    filled: true
                    enabled: root.canStart
                    onClicked: root.machine.startCycle(root.program.recipe(), root.program.dieRadius,
                                                       root.program.tubeDiameter)
                }

                HmiButton {
                    id: stopButton

                    objectName: "stopButton"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 106
                    Layout.maximumWidth: 124
                    Layout.preferredHeight: 72
                    text: qsTr("STOP")
                    accent: Theme.danger
                    filled: true
                    onClicked: root.machine.stop()
                }
            }

            // Arıza şeridi: yalnızca silinmemiş arıza varken görünür ve her sayfada durur
            // (operatör hangi sayfada olursa olsun arızayı görmeli). Üst şeridin üstüne
            // biner: sayfalardan yer almadığı için hiçbir sayfanın yerleşimi bozulmaz.
            // Arıza varken eksen konumlarının yerini arıza alır; konumlar HAREKET
            // sayfasında da durur. BAŞLAT ve STOP açıkta kalır.
            // RESET sebebi geçmiş arızaları siler; sebebi süren arıza (ör. acil stop
            // basılı) silinmez, buton kapalı kalır.
            Rectangle {
                objectName: "alarmBanner"
                visible: root.machine.hasAlarm
                anchors.left: parent.left
                anchors.right: parent.right
                // BAŞLAT ve STOP açıkta kalsın: şerit onların soluna kadar uzanır.
                anchors.rightMargin: startButton.width + stopButton.width + topStrip.spacing * 2
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                radius: Theme.radius
                color: "#f9e6e6" // üst şeridin üstünü kapatır: saydam olmamalı
                border.color: Theme.danger
                border.width: 2

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 8
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            objectName: "alarmTitle"
                            Layout.fillWidth: true
                            text: root.machine.alarmCount > 1
                                  ? qsTr("ARIZA: %1  ·  +%2 arıza daha").arg(root.machine.alarmTitle)
                                                                        .arg(root.machine.alarmCount - 1)
                                  : qsTr("ARIZA: %1").arg(root.machine.alarmTitle)
                            font.pixelSize: 17
                            font.bold: true
                            color: Theme.danger
                            elide: Text.ElideRight
                        }

                        Text {
                            objectName: "alarmDetail"
                            Layout.fillWidth: true
                            text: root.machine.alarmDetail
                            font.pixelSize: 13
                            color: Theme.text
                            // Ayrıntı uzun olabilir: iki satıra sarar, yine sığmazsa kısalır
                            // (tamamı her zaman arıza geçmişinde durur).
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }

                    HmiButton {
                        objectName: "alarmHistoryButton"
                        implicitWidth: 112
                        implicitHeight: 44
                        padding: 6
                        font.pixelSize: 15
                        text: qsTr("GEÇMİŞ")
                        onClicked: alarmsDialog.open()
                    }

                    HmiButton {
                        objectName: "resetButton"
                        implicitWidth: 112
                        implicitHeight: 44
                        padding: 6
                        font.pixelSize: 15
                        text: qsTr("RESET")
                        accent: Theme.danger
                        filled: true
                        enabled: root.machine.canResetAlarms
                        onClicked: root.machine.resetAlarms()
                    }
                }
            }
        }

        // Orta bölüm: solda menü, sağda seçili sayfa
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            // Sol menü: sayfa adları mevcut makine ekranındakilerle aynı.
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 160
                radius: Theme.radius
                color: Theme.panel
                border.color: Theme.panelBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    NavButton {
                        objectName: "navProduction"
                        Layout.fillWidth: true
                        text: qsTr("ÜRETİM")
                        selected: root.currentPage === 0
                        onClicked: root.currentPage = 0
                    }

                    NavButton {
                        objectName: "navDesign"
                        Layout.fillWidth: true
                        text: qsTr("TASARIM")
                        selected: root.currentPage === 1
                        onClicked: root.currentPage = 1
                    }

                    NavButton {
                        objectName: "navDies"
                        Layout.fillWidth: true
                        text: qsTr("KALIPLAR")
                        selected: root.currentPage === 2
                        onClicked: root.currentPage = 2
                    }

                    NavButton {
                        objectName: "navMotion"
                        Layout.fillWidth: true
                        text: qsTr("HAREKET")
                        selected: root.currentPage === 3
                        onClicked: root.currentPage = 3
                    }

                    NavButton {
                        objectName: "navSettings"
                        Layout.fillWidth: true
                        text: qsTr("AYARLAR")
                        selected: root.currentPage === 4
                        onClicked: root.currentPage = 4
                    }

                    NavButton {
                        objectName: "navTimers"
                        Layout.fillWidth: true
                        text: qsTr("ZAMANLAR")
                        selected: root.currentPage === 5
                        onClicked: root.currentPage = 5
                    }

                    NavButton {
                        objectName: "navIo"
                        Layout.fillWidth: true
                        text: qsTr("IO TEST")
                        selected: root.currentPage === 6
                        onClicked: root.currentPage = 6
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.currentPage

                ProductionPage {
                    machine: root.machine
                    program: root.program
                    manager: programManager
                    dies: root.dies
                    toolingProblem: root.toolingProblem
                    onDiesRequested: root.currentPage = 2
                }

                DesignPage {
                    program: root.program
                    manager: programManager
                    dies: root.dies
                    toolingProblem: root.toolingProblem
                }

                DiesPage {
                    dies: root.dies
                    machine: root.machine
                }

                MotionPage {
                    machine: root.machine
                }

                SettingsPage {
                    machine: root.machine
                    access: root.access
                }

                TimersPage {
                    machine: root.machine
                    access: root.access
                }

                IoTestPage {
                    machine: root.machine
                    access: root.access
                }
            }
        }

        // Alt şerit: çalışma modu ve saat
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap

            Rectangle {
                visible: root.machine.simulation
                implicitWidth: simText.implicitWidth + 28
                implicitHeight: 30
                radius: 15
                color: "transparent"
                border.color: Theme.active
                border.width: 2

                // "SİMÜLASYON" sekmesiyle karışmasın diye: sanal makine (SimMachine) çalışıyor.
                Text {
                    id: simText

                    anchors.centerIn: parent
                    text: qsTr("SANAL MAKİNE · gerçek makineye bağlı değil")
                    font.pixelSize: Theme.fontSmall
                    font.bold: true
                    color: Theme.text
                }
            }

            // Ayar kilidi açıkken her sayfadan görünür; dokununca hemen kilitlenir.
            Rectangle {
                objectName: "accessBadge"
                visible: root.access.unlocked
                implicitWidth: accessText.implicitWidth + 28
                implicitHeight: 30
                radius: 15
                color: Theme.ok

                Text {
                    id: accessText

                    anchors.centerIn: parent
                    text: qsTr("AYAR AÇIK · %1 · KİLİTLE").arg(
                              Math.floor(root.access.remainingSeconds / 60) + ":"
                              + String(root.access.remainingSeconds % 60).padStart(2, "0"))
                    font.pixelSize: Theme.fontSmall
                    font.bold: true
                    color: "white"
                }

                TapHandler {
                    onTapped: root.access.lock()
                }
            }

            HmiButton {
                objectName: "historyButton"
                implicitWidth: 156
                implicitHeight: 30
                padding: 4
                font.pixelSize: 13
                text: root.machine.alarms.count > 0 ? qsTr("ARIZA GEÇMİŞİ (%1)").arg(root.machine.alarms.count)
                                                    : qsTr("ARIZA GEÇMİŞİ")
                accent: Theme.textMuted
                onClicked: alarmsDialog.open()
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                id: clock

                font.pixelSize: Theme.fontSmall
                color: Theme.textMuted
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: clock.text = Qt.formatDateTime(new Date(), "dd.MM.yyyy  HH:mm:ss")
    }

    // Arıza geçmişi penceresi (arıza şeridinden ve alt şeritten açılır).
    AlarmsDialog {
        id: alarmsDialog

        machine: root.machine
    }

    // Program dosya işlemleri ve pencereleri (kaydet, aç, programlar listesi).
    ProgramManager {
        id: programManager

        program: root.program
        store: root.store
        onCloseApproved: {
            root.exitConfirmed = true
            root.close()
        }
    }
}
