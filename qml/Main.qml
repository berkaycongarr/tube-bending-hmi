import QtQuick
import QtQuick.Layouts

// Ana ekran: üstte durum, eksen konumları ve STOP; solda menü; ortada seçili
// sayfa; altta çalışma modu ve saat. Üst şerit her sayfada görünür kalır.
Window {
    id: root

    // main.cpp tarafından verilen makine nesnesi (demoda SimMachine).
    required property Machine machine

    // main.cpp tarafından verilen büküm programı (reçete).
    required property BendProgram program

    // main.cpp tarafından verilen program deposu (Belgeler\BoruBukme\Programlar).
    required property ProgramStore store

    // Seçili sayfa: 0 = Üretim, 1 = Tasarım, 2 = Hareket
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

    readonly property string stateText: {
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
        switch (machine.state) {
        case Machine.Homing:
            return Theme.active
        case Machine.Ready:
            return Theme.ok
        default:
            return Theme.idle
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // Üst şerit: durum, eksen konumları, STOP.
        // Dar ekranda (1024 px) eksen kutuları 190'dan 145 px'e kadar daralır;
        // durum kutusu en az 220 px kalır ki makinenin durumu her zaman okunsun.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.minimumWidth: 220
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
                Layout.minimumWidth: 145
                Layout.maximumWidth: 190
                axis: root.machine.axisX
                title: qsTr("İlerletme")
            }

            AxisDisplay {
                Layout.fillWidth: true
                Layout.minimumWidth: 145
                Layout.maximumWidth: 190
                axis: root.machine.axisB
                title: qsTr("Büküm")
            }

            AxisDisplay {
                Layout.fillWidth: true
                Layout.minimumWidth: 145
                Layout.maximumWidth: 190
                axis: root.machine.axisA
                title: qsTr("Rotasyon")
            }

            AxisDisplay {
                Layout.fillWidth: true
                Layout.minimumWidth: 145
                Layout.maximumWidth: 190
                axis: root.machine.axisY
                title: qsTr("Öteleme")
            }

            HmiButton {
                objectName: "stopButton"
                Layout.preferredWidth: 140
                Layout.preferredHeight: 72
                text: qsTr("STOP")
                accent: Theme.danger
                filled: true
                onClicked: root.machine.stop()
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
                        objectName: "navMotion"
                        Layout.fillWidth: true
                        text: qsTr("HAREKET")
                        selected: root.currentPage === 2
                        onClicked: root.currentPage = 2
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
                }

                DesignPage {
                    program: root.program
                    manager: programManager
                }

                MotionPage {
                    machine: root.machine
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

                Text {
                    id: simText

                    anchors.centerIn: parent
                    text: qsTr("SİMÜLASYON · gerçek makineye bağlı değil")
                    font.pixelSize: Theme.fontSmall
                    font.bold: true
                    color: Theme.text
                }
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
