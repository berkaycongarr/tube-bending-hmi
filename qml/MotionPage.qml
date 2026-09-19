import QtQuick
import QtQuick.Layouts

// Hareket sayfası: eksenleri elle kumanda etme.
//   − / +  basılı tuttukça eksen hareket eder (jog, push buton)
//   Hedef  değer girilir, GİT'e basınca eksen o konuma gider (değer gir, değer gör)
Rectangle {
    id: page

    required property Machine machine

    // Seçili jog hızı. Güvenli olan yavaş hızla başlar.
    property bool fast: false

    // Hızlı jog yalnızca makine HAZIR iken (tüm eksenler referanslıyken) geçerlidir.
    readonly property bool fastActive: page.fast && page.machine.state === Machine.Ready

    radius: Theme.radius
    color: Theme.panel
    border.color: Theme.panelBorder

    // Makine HAZIR durumundan çıkarsa (ör. yeniden referans aranırsa) jog hızı
    // yavaşa döner; hızlıyı operatör bilerek yeniden seçmelidir.
    Connections {
        target: page.machine

        function onStateChanged() {
            if (page.machine.state !== Machine.Ready)
                page.fast = false
        }
    }

    // Dört eksen satırı ve hidrolik, 1024x720 ekrana da sığacak şekilde sıkı yerleşir.
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        // Başlık ve jog hızı seçimi
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: qsTr("Elle Kumanda")
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                    color: Theme.text
                }

                Text {
                    objectName: "motionHint"
                    Layout.fillWidth: true
                    text: qsTr("− / + basılı tutulduğu sürece eksen hareket eder. "
                               + "Hedef girip GİT'e basınca eksen o konuma gider.")
                    font.pixelSize: 13
                    color: Theme.textMuted
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            Text {
                Layout.maximumWidth: 150
                horizontalAlignment: Text.AlignRight
                text: page.machine.state === Machine.Ready ? qsTr("Jog hızı")
                                                           : qsTr("Hızlı jog referanstan sonra")
                font.pixelSize: Theme.fontSmall
                color: Theme.textMuted
                wrapMode: Text.WordWrap
            }

            HmiButton {
                objectName: "speedSlow"
                implicitWidth: 100
                implicitHeight: 44
                font.pixelSize: 16
                text: qsTr("YAVAŞ")
                filled: !page.fastActive
                onClicked: page.fast = false
            }

            HmiButton {
                objectName: "speedFast"
                implicitWidth: 100
                implicitHeight: 44
                font.pixelSize: 16
                text: qsTr("HIZLI")
                filled: page.fastActive
                enabled: page.machine.state === Machine.Ready
                onClicked: page.fast = true
            }
        }

        JogRow {
            Layout.fillWidth: true
            machine: page.machine
            axis: page.machine.axisX
            title: qsTr("İlerletme")
            fast: page.fastActive
        }

        JogRow {
            Layout.fillWidth: true
            machine: page.machine
            axis: page.machine.axisB
            title: qsTr("Büküm")
            fast: page.fastActive
        }

        JogRow {
            Layout.fillWidth: true
            machine: page.machine
            axis: page.machine.axisA
            title: qsTr("Rotasyon")
            fast: page.fastActive
        }

        JogRow {
            Layout.fillWidth: true
            machine: page.machine
            axis: page.machine.axisY
            title: qsTr("Öteleme")
            fast: page.fastActive
        }

        // Hidrolik: pompa (normal start/stop) ve silindirler (kalıcı butonlar).
        // Bölüm adı, eksenlerden ayıran çizginin başında durur.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: qsTr("Hidrolik")
                font.pixelSize: Theme.fontSmall
                font.bold: true
                color: Theme.textMuted
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.panelBorder
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            PumpControl {
                Layout.fillWidth: true
                Layout.minimumWidth: 260
                Layout.preferredWidth: 300
                Layout.preferredHeight: 104
                machine: page.machine
            }

            ActuatorButton {
                objectName: "clampButton"
                Layout.fillWidth: true
                Layout.minimumWidth: 160
                Layout.preferredHeight: 104
                machine: page.machine
                actuator: page.machine.clamp
                title: qsTr("MENGENE")
                onText: qsTr("KAPALI")
                offText: qsTr("AÇIK")
                turningOnText: qsTr("KAPANIYOR…")
                turningOffText: qsTr("AÇILIYOR…")
            }

            ActuatorButton {
                objectName: "mandrelButton"
                Layout.fillWidth: true
                Layout.minimumWidth: 160
                Layout.preferredHeight: 104
                machine: page.machine
                actuator: page.machine.mandrel
                title: qsTr("MALAFA")
                onText: qsTr("İLERİDE")
                offText: qsTr("GERİDE")
                turningOnText: qsTr("İLERİ GİDİYOR…")
                turningOffText: qsTr("GERİ GELİYOR…")
            }

            ActuatorButton {
                objectName: "colletButton"
                Layout.fillWidth: true
                Layout.minimumWidth: 160
                Layout.preferredHeight: 104
                machine: page.machine
                actuator: page.machine.collet
                title: qsTr("PENS")
                onText: qsTr("KAPALI")
                offText: qsTr("AÇIK")
                turningOnText: qsTr("KAPANIYOR…")
                turningOffText: qsTr("AÇILIYOR…")
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }

    // Bir eksenin satırı: ad, konum ve bilgi satırı, hedef ve GİT, − / + butonları.
    component JogRow: Rectangle {
        id: row

        required property Machine machine
        required property Axis axis
        required property string title
        property bool fast: false

        // "Değer gir": girilen hedef konum (NaN: henüz girilmedi).
        property real targetValue: NaN

        readonly property bool hasTarget: !isNaN(row.targetValue)
        // Eksen kilitli mi (ör. mengene boruyu tutuyor)?
        readonly property bool locked: row.axis.interlock !== Axis.NoInterlock
        // Hedefe gitmek için referans şart (0'ın nerede olduğu bilinmeli) ve kilit olmamalı.
        readonly property bool canPosition: row.axis.homed && row.machine.state === Machine.Ready
                                            && !row.locked
        readonly property bool atTarget: row.hasTarget && !row.axis.moving
                                         && Math.abs(row.axis.position - row.targetValue) < 0.005

        function formatValue(value: real): string {
            return value.toFixed(2) + (row.axis.rotary ? "°" : " mm")
        }

        function formatSpeed(value: real): string {
            return value.toFixed(0) + (row.axis.rotary ? " °/sn" : " mm/sn")
        }

        // Konumun altındaki bilgi: anlık jog hızı, kilit ve limit durumu.
        readonly property string info: {
            const speed = qsTr("Jog %1").arg(row.formatSpeed(row.fast ? row.axis.jogSpeedFast
                                                                      : row.axis.jogSpeedSlow))
            if (row.axis.interlock === Axis.ClampClosed)
                return speed + qsTr(" · Kilitli: mengene boruyu tutuyor")
            if (!row.axis.homed)
                return speed + qsTr(" · Referanssız: limitler devre dışı")
            if (row.axis.atMinLimit)
                return speed + qsTr(" · Alt limitte (%1)").arg(row.formatValue(row.axis.minPosition))
            if (row.axis.atMaxLimit)
                return speed + qsTr(" · Üst limitte (%1)").arg(row.formatValue(row.axis.maxPosition))
            return speed + qsTr(" · Limit %1 … %2").arg(row.formatValue(row.axis.minPosition))
                                                     .arg(row.formatValue(row.axis.maxPosition))
        }

        objectName: "row" + row.axis.name
        implicitHeight: 70
        radius: Theme.radius
        color: "transparent"
        border.color: row.axis.moving ? Theme.active : Theme.panelBorder
        border.width: row.axis.moving ? 2 : 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 12
            spacing: 10

            // Sütun genişlikleri sabit: dar pencerede de satırlar alt alta hizalı kalır.
            ColumnLayout {
                Layout.minimumWidth: 90
                Layout.maximumWidth: 90
                spacing: 0

                Text {
                    text: row.axis.name
                    font.pixelSize: 30
                    font.bold: true
                    color: Theme.text
                }

                Text {
                    text: row.title
                    font.pixelSize: Theme.fontNormal
                    color: Theme.textMuted
                }
            }

            // "Değer gör": eksenin gerçek konumu
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 190
                spacing: 2

                Text {
                    text: row.formatValue(row.axis.position)
                    font.pixelSize: 28
                    font.bold: true
                    color: Theme.text
                }

                Text {
                    Layout.fillWidth: true
                    text: row.info
                    font.pixelSize: 13
                    color: row.axis.homed && !row.locked ? Theme.textMuted : Theme.activeText
                    elide: Text.ElideRight
                }
            }

            ValueField {
                objectName: "target" + row.axis.name
                Layout.minimumWidth: 144
                Layout.maximumWidth: 144
                Layout.preferredHeight: 58
                topPadding: 5
                bottomPadding: 5
                caption: row.atTarget ? qsTr("Hedefte ✓") : qsTr("Hedef")
                captionColor: row.atTarget ? Theme.ok : Theme.textMuted
                text: row.hasTarget ? row.formatValue(row.targetValue) : "—"
                enabled: row.canPosition
                onClicked: keypad.open()
            }

            HmiButton {
                objectName: "go" + row.axis.name
                Layout.minimumWidth: 80
                Layout.maximumWidth: 80
                Layout.preferredHeight: 58
                text: qsTr("GİT")
                enabled: row.canPosition && row.hasTarget && !row.axis.moving && !row.atTarget
                onClicked: row.machine.moveTo(row.axis, row.targetValue)
            }

            JogButton {
                objectName: "jog" + row.axis.name + "Minus"
                Layout.minimumWidth: 88
                Layout.maximumWidth: 88
                Layout.preferredHeight: 58
                machine: row.machine
                axis: row.axis
                direction: -1
                fast: row.fast
            }

            JogButton {
                objectName: "jog" + row.axis.name + "Plus"
                Layout.minimumWidth: 88
                Layout.maximumWidth: 88
                Layout.preferredHeight: 58
                machine: row.machine
                axis: row.axis
                direction: 1
                fast: row.fast
            }
        }

        NumericKeypad {
            id: keypad

            title: qsTr("%1 · %2: hedef konum").arg(row.axis.name).arg(row.title)
            unit: row.axis.rotary ? "°" : "mm"
            minimum: row.axis.minPosition
            maximum: row.axis.maxPosition
            note: qsTr("Şu anki konum: %1").arg(row.formatValue(row.axis.position))
            onValueEntered: value => {
                row.targetValue = value
            }
        }
    }
}
