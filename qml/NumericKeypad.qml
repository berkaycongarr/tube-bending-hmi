// Repeater'ın ürettiği tuşlar bu dosyadaki "pad" kimliğine güvenle erişebilsin.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

// Dokunmatik sayı tuş takımı ("değer gir").
// Girilen değer [minimum, maximum] aralığında değilse TAMAM'a basılamaz.
// Bilgisayarda klavyeyle de yazılabilir: rakamlar, nokta/virgül, eksi, silme, Enter.
T.Popup {
    id: pad

    property string title
    property string unit          // "mm" ya da "°"
    property real minimum: 0
    property real maximum: 0
    property real current: 0      // eksenin şu anki konumu (bilgi için)

    property string entry: ""     // yazılan metin

    signal valueEntered(real value)

    readonly property real value: Number(pad.entry)
    readonly property bool complete: pad.entry.length > 0 && pad.entry !== "-" && !isNaN(pad.value)
    readonly property bool inRange: pad.complete && pad.value >= pad.minimum && pad.value <= pad.maximum

    function formatValue(v: real): string {
        return v.toFixed(2) + (pad.unit === "°" ? "°" : " " + pad.unit)
    }

    function press(key: string) {
        if (key === "⌫") {
            pad.entry = pad.entry.slice(0, -1)
        } else if (key === "C") {
            pad.entry = ""
        } else if (key === "±") {
            pad.entry = pad.entry.startsWith("-") ? pad.entry.slice(1) : "-" + pad.entry
        } else if (key === ".") {
            if (!pad.entry.includes("."))
                pad.entry += (pad.entry === "" || pad.entry === "-") ? "0." : "."
        } else {
            // Rakam: en fazla 2 ondalık ve 6 tam basamak; baştaki gereksiz 0 yazılmaz.
            const dot = pad.entry.indexOf(".")
            if (dot >= 0 && pad.entry.length - dot > 2)
                return
            if (dot < 0 && pad.entry.replace("-", "").length >= 6)
                return
            if (pad.entry === "0" || pad.entry === "-0")
                pad.entry = pad.entry.slice(0, -1)
            pad.entry += key
        }
    }

    function confirm() {
        if (!pad.inRange)
            return
        pad.valueEntered(pad.value)
        pad.close()
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
    padding: 20
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside

    onAboutToShow: pad.entry = ""

    // Tuş takımı açıkken arkadaki ekran karartılır ve dokunmaya kapanır.
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
        focus: true

        Keys.onPressed: event => {
            const k = event.key
            if (k >= Qt.Key_0 && k <= Qt.Key_9)
                pad.press(String(k - Qt.Key_0))
            else if (k === Qt.Key_Period || k === Qt.Key_Comma)
                pad.press(".")
            else if (k === Qt.Key_Minus)
                pad.press("±")
            else if (k === Qt.Key_Backspace)
                pad.press("⌫")
            else if (k === Qt.Key_Return || k === Qt.Key_Enter)
                pad.confirm()
            else
                return
            event.accepted = true
        }

        Text {
            text: pad.title
            font.pixelSize: Theme.fontTitle
            font.bold: true
            color: Theme.text
        }

        Text {
            text: qsTr("Aralık: %1 … %2").arg(pad.formatValue(pad.minimum)).arg(pad.formatValue(pad.maximum))
            font.pixelSize: Theme.fontSmall
            color: Theme.textMuted
        }

        Text {
            text: qsTr("Şu anki konum: %1").arg(pad.formatValue(pad.current))
            font.pixelSize: Theme.fontSmall
            color: Theme.textMuted
        }

        // Yazılan değer. Aralık dışındaysa çerçeve kırmızı olur.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 64
            radius: Theme.radius
            color: Theme.field
            border.width: 2
            border.color: pad.complete && !pad.inRange ? Theme.danger : Theme.panelBorder

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: (pad.entry.length > 0 ? pad.entry : "0") + (pad.unit === "°" ? "°" : " " + pad.unit)
                font.pixelSize: 30
                font.bold: true
                color: pad.entry.length > 0 ? Theme.text : Theme.idle
            }
        }

        Text {
            objectName: "keypadError"
            text: pad.complete && !pad.inRange ? qsTr("Değer aralık dışında") : " "
            font.pixelSize: Theme.fontSmall
            font.bold: true
            color: Theme.danger
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 4
            rowSpacing: 8
            columnSpacing: 8

            Repeater {
                model: ["7", "8", "9", "⌫", "4", "5", "6", "C", "1", "2", "3", "±", "0", "."]

                delegate: HmiButton {
                    required property string modelData

                    objectName: "key" + (modelData === "⌫" ? "Back"
                                         : modelData === "±" ? "Sign"
                                         : modelData === "." ? "Dot" : modelData)
                    Layout.fillWidth: true
                    Layout.columnSpan: modelData === "0" ? 3 : 1
                    implicitWidth: 76
                    implicitHeight: 60
                    text: modelData
                    font.pixelSize: 24
                    focusPolicy: Qt.NoFocus
                    onClicked: pad.press(modelData)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8

            HmiButton {
                objectName: "keypadCancel"
                Layout.fillWidth: true
                implicitHeight: 60
                text: qsTr("İPTAL")
                focusPolicy: Qt.NoFocus
                onClicked: pad.close()
            }

            HmiButton {
                objectName: "keypadOk"
                Layout.fillWidth: true
                implicitHeight: 60
                text: qsTr("TAMAM")
                accent: Theme.ok
                filled: true
                enabled: pad.inRange
                focusPolicy: Qt.NoFocus
                onClicked: pad.confirm()
            }
        }
    }
}
