import QtQuick
import QtQuick.Layouts

// ÜRETİM sayfası: solda açık program (salt okunur tablo, boru ve kalıp bilgileri,
// üretime hazır mı?), sağda referans arama. Program buradan da yüklenebilir
// (PROGRAM YÜKLE); düzenleme TASARIM sayfasında yapılır. Üretim döngüsü (START)
// sonraki adımda bu sayfaya eklenecek.
Rectangle {
    id: page

    required property Machine machine
    required property BendProgram program
    required property ProgramManager manager

    // Mengene boruyu tutuyorsa ya da üretim döngüsü çalışıyorsa X, A ve Y
    // kilitlidir; bu eksenler hareket ettiği için referans arama da kilitlenir.
    readonly property bool axesLocked: page.machine.axisX.interlock !== Axis.NoInterlock
                                       || page.machine.axisA.interlock !== Axis.NoInterlock
                                       || page.machine.axisY.interlock !== Axis.NoInterlock

    readonly property string homeLockReason: {
        if (!page.axesLocked)
            return ""
        if (page.machine.axisX.interlock === Axis.CycleRunning)
            return qsTr("Kilitli: üretim döngüsü çalışıyor")
        return qsTr("Kilitli: referans aramak için önce mengeneyi açın")
    }

    // Programın kendi sorunları (makineden bağımsız)
    readonly property string programProblems: {
        const problems = []
        if (page.program.count === 0)
            problems.push(qsTr("Program boş"))
        else if (page.program.remainingLength < -0.001)
            problems.push(qsTr("Boru %1 mm kısa").arg((-page.program.remainingLength).toFixed(2)))
        if (page.program.invalidStepCount > 0)
            problems.push(qsTr("%1 adımda sınır dışı değer").arg(page.program.invalidStepCount))
        return problems.join(" · ")
    }

    // Üretime engel olan her şey: makine hazır değilse ve programın sorunları.
    readonly property string blockReason: {
        const reasons = []
        if (page.machine.state === Machine.Homing)
            reasons.push(qsTr("Referans aranıyor"))
        else if (page.machine.state !== Machine.Ready)
            reasons.push(qsTr("Makine referanssız"))
        if (page.programProblems.length > 0)
            reasons.push(page.programProblems)
        return reasons.join(" · ")
    }

    readonly property bool ready: page.blockReason.length === 0

    // Renk anlam taşır: yeşil hazır, kırmızı program hatalı, turuncu makine bekliyor.
    readonly property color readinessColor: page.ready ? Theme.ok
                                            : page.programProblems.length > 0 ? Theme.danger
                                                                              : Theme.active

    function formatMm(value: real): string {
        return value.toFixed(2) + " mm"
    }

    radius: Theme.radius
    color: Theme.panel
    border.color: Theme.panelBorder

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // ---------------- Sol: açık program ----------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

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
                    implicitWidth: 180
                    implicitHeight: 52
                    font.pixelSize: 15
                    text: qsTr("PROGRAM YÜKLE")
                    onClicked: page.manager.loadProgram()
                }
            }

            // TASARIM'daki tablonun aynısı, yalnızca gösterir.
            ProgramTable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                program: page.program
                emptyText: qsTr("Program boş. TASARIM sayfasında adım ekleyin ya da program yükleyin.")
            }

            // Boru ve kalıp bilgileri, açınım boyu
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                InfoChip {
                    objectName: "infoTubeLength"
                    caption: qsTr("Boru boyu")
                    value: page.formatMm(page.program.tubeLength)
                }

                InfoChip {
                    caption: qsTr("Boru çapı")
                    value: page.formatMm(page.program.tubeDiameter)
                }

                InfoChip {
                    caption: qsTr("Kalıp yarıçapı")
                    value: page.formatMm(page.program.dieRadius)
                }

                InfoChip {
                    objectName: "infoDeveloped"
                    caption: qsTr("Açınım boyu")
                    value: page.formatMm(page.program.developedLength)
                }
            }

            // Üretime hazır mı? Değilse nedenleri.
            Rectangle {
                objectName: "readiness"
                Layout.fillWidth: true
                implicitHeight: 56
                radius: Theme.radius
                color: Theme.field
                border.color: Theme.panelBorder

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 8
                    radius: Theme.radius
                    color: page.readinessColor
                }

                Text {
                    objectName: "readinessText"
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: page.ready ? qsTr("✓ Üretime hazır")
                                     : qsTr("Üretime hazır değil: %1").arg(page.blockReason)
                    font.pixelSize: 15
                    font.bold: true
                    color: page.ready ? Theme.ok
                           : page.programProblems.length > 0 ? Theme.danger : Theme.activeText
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }
        }

        // ---------------- Sağ: referans arama ----------------
        ColumnLayout {
            Layout.fillWidth: false
            Layout.preferredWidth: 260
            Layout.fillHeight: true
            spacing: 8

            Text {
                text: qsTr("Referans Arama")
                font.pixelSize: Theme.fontTitle
                font.bold: true
                color: Theme.text
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Eksenler sırayla referans noktasına gider; orada eksene bilinen "
                           + "bir değer yazılır ve gerçek konumu belirlenmiş olur.")
                font.pixelSize: 13
                color: Theme.textMuted
                wrapMode: Text.WordWrap
            }

            HomingStep {
                Layout.fillWidth: true
                order: 1
                axis: page.machine.axisB
                title: qsTr("Büküm")
            }

            HomingStep {
                Layout.fillWidth: true
                order: 2
                axis: page.machine.axisY
                title: qsTr("Öteleme")
            }

            HomingStep {
                Layout.fillWidth: true
                order: 3
                axis: page.machine.axisA
                title: qsTr("Rotasyon")
            }

            HomingStep {
                Layout.fillWidth: true
                order: 4
                axis: page.machine.axisX
                title: qsTr("İlerletme")
            }

            HmiButton {
                objectName: "homeButton"
                Layout.fillWidth: true
                Layout.topMargin: 4
                implicitHeight: 60
                font.pixelSize: 16
                text: page.machine.state === Machine.Ready ? qsTr("TEKRAR REFERANS ARA")
                                                           : qsTr("REFERANS ARA (HOME)")
                enabled: page.machine.state !== Machine.Homing && !page.axesLocked
                onClicked: page.machine.startHoming()
            }

            // Referans aramada X, A ve Y hareket eder; kilitliyken aranamaz.
            Text {
                objectName: "homeLockHint"
                Layout.fillWidth: true
                visible: page.axesLocked && page.machine.state !== Machine.Homing
                text: page.homeLockReason
                font.pixelSize: Theme.fontSmall
                font.bold: true
                color: Theme.activeText
                wrapMode: Text.WordWrap
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }

    // Referans arama adımlarından biri: sıra, eksen ve adı, referans değeri, durum.
    component HomingStep: Rectangle {
        id: step

        required property int order
        required property Axis axis
        required property string title

        objectName: "homingStep" + step.axis.name
        implicitHeight: 50
        radius: Theme.radius
        color: step.axis.homing ? "#1ac77800" : "transparent"
        border.color: step.axis.homing ? Theme.active : Theme.panelBorder

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            Rectangle {
                implicitWidth: 26
                implicitHeight: 26
                radius: 13
                color: step.axis.homed ? Theme.ok : step.axis.homing ? Theme.active : Theme.idle

                Text {
                    anchors.centerIn: parent
                    text: step.axis.homed ? "✓" : step.order.toString()
                    font.pixelSize: 13
                    font.bold: true
                    color: "white"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: step.axis.name + "  " + step.title
                    font.pixelSize: 15
                    font.bold: true
                    color: Theme.text
                    elide: Text.ElideRight
                }

                // Referans noktasında eksene yazılacak değer
                Text {
                    text: "→ " + step.axis.homePosition.toFixed(2) + (step.axis.rotary ? "°" : " mm")
                    font.pixelSize: 12
                    color: Theme.textMuted
                }
            }

            // Durum sütunu en uzun yazıya ("Aranıyor…", kalın) göre geniş tutulur.
            Text {
                objectName: "homingState"
                Layout.preferredWidth: 86
                horizontalAlignment: Text.AlignRight
                text: step.axis.homed ? qsTr("Tamam")
                                      : step.axis.homing ? qsTr("Aranıyor…") : qsTr("Bekliyor")
                font.pixelSize: Theme.fontSmall
                font.bold: step.axis.homing
                color: step.axis.homed ? Theme.ok : Theme.textMuted
            }
        }
    }

    // Küçük bilgi kutusu: üstte başlık, altta değer.
    component InfoChip: Rectangle {
        id: chip

        required property string caption
        required property string value

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 56
        radius: Theme.radius
        color: Theme.field
        border.color: Theme.panelBorder

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: chip.caption
                font.pixelSize: 12
                font.bold: true
                color: Theme.textMuted
                elide: Text.ElideRight
            }

            Text {
                objectName: "chipValue"
                width: parent.width
                text: chip.value
                font.pixelSize: Theme.fontNormal
                font.bold: true
                color: Theme.text
                elide: Text.ElideRight
            }
        }
    }
}
