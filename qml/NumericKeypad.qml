// Repeater'ın ürettiği tuşlar bu dosyadaki "pad" kimliğine güvenle erişebilsin.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

// Dokunmatik sayı tuş takımı ("değer gir").
// Girilen değer [minimum, maximum] aralığında değilse TAMAM'a basılamaz.
// Bilgisayarda klavyeyle de yazılabilir: rakamlar, nokta/virgül, eksi, silme, Enter.
//
// Şifre için de kullanılır (secret): rakamlar • olarak görünür, nokta ve eksi yoktur,
// TAMAM'da secretEntered bildirilir ve pencere açık kalır (şifreyi sahibi denetler:
// doğruysa kapatır, yanlışsa errorText ile söyler).
T.Popup {
    id: pad

    property string title
    property string unit          // "mm", "°" ya da "s"
    property real minimum: 0
    property real maximum: 0
    property string note          // aralığın altında gösterilen bilgi (ör. şu anki değer)
    // Varsayılan değer (ayarlarda): verilirse "VARSAYILAN" butonu onu yazar. NaN: buton yok.
    property real defaultValue: NaN

    property bool secret: false   // şifre girişi
    property int secretMinimum: 4 // şifre en az / en çok kaç rakam
    property int secretMaximum: 8
    property string errorText: "" // sahibinin bildirdiği hata (ör. "Şifre yanlış")

    property string entry: ""     // yazılan metin

    signal valueEntered(real value)
    signal secretEntered(string text)

    readonly property real value: Number(pad.entry)
    readonly property bool complete: pad.entry.length > 0 && pad.entry !== "-" && !isNaN(pad.value)
    readonly property bool inRange: pad.complete && pad.value >= pad.minimum && pad.value <= pad.maximum
    readonly property bool canConfirm: pad.secret ? pad.entry.length >= pad.secretMinimum : pad.inRange

    // Yeni bir şey yazılınca eski hata kalkar.
    onEntryChanged: pad.errorText = ""

    function formatValue(v: real): string {
        return v.toFixed(2) + (pad.unit === "°" ? "°" : " " + pad.unit)
    }

    function press(key: string) {
        if (pad.secret && (key === "±" || key === "."))
            return
        if (pad.secret && key !== "⌫" && key !== "C") {
            if (pad.entry.length < pad.secretMaximum)
                pad.entry += key
            return
        }
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
        if (!pad.canConfirm)
            return
        if (pad.secret) {
            pad.secretEntered(pad.entry)
            return
        }
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

    onAboutToShow: {
        pad.entry = ""
        pad.errorText = ""
    }

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
            objectName: "keypadTitle"
            text: pad.title
            font.pixelSize: Theme.fontTitle
            font.bold: true
            color: Theme.text
        }

        Text {
            visible: !pad.secret
            text: qsTr("Aralık: %1 … %2").arg(pad.formatValue(pad.minimum)).arg(pad.formatValue(pad.maximum))
            font.pixelSize: Theme.fontSmall
            color: Theme.textMuted
        }

        Text {
            visible: pad.note.length > 0
            text: pad.note
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
            border.color: pad.errorText.length > 0 || (!pad.secret && pad.complete && !pad.inRange)
                          ? Theme.danger : Theme.panelBorder

            // Şifre yazılırken rakamlar görünmez: her rakam için bir nokta.
            Text {
                objectName: "keypadEntry"
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: pad.secret ? (pad.entry.length > 0 ? "●".repeat(pad.entry.length) : "—")
                                 : (pad.entry.length > 0 ? pad.entry : "0")
                                   + (pad.unit === "°" ? "°" : " " + pad.unit)
                font.pixelSize: 30
                font.bold: true
                font.letterSpacing: pad.secret ? 6 : 0
                color: pad.entry.length > 0 ? Theme.text : Theme.idle
            }
        }

        Text {
            objectName: "keypadError"
            text: pad.errorText.length > 0 ? pad.errorText
                  : !pad.secret && pad.complete && !pad.inRange ? qsTr("Değer aralık dışında") : " "
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
                    // Şifrede nokta ve eksi yoktur.
                    enabled: !(pad.secret && (modelData === "±" || modelData === "."))
                    onClicked: pad.press(modelData)
                }
            }
        }

        HmiButton {
            objectName: "keypadDefault"
            Layout.fillWidth: true
            Layout.topMargin: 4
            visible: !pad.secret && !isNaN(pad.defaultValue)
            implicitHeight: 48
            font.pixelSize: 16
            text: qsTr("VARSAYILAN: %1").arg(pad.formatValue(pad.defaultValue))
            focusPolicy: Qt.NoFocus
            onClicked: pad.entry = Number(pad.defaultValue.toFixed(2)).toString()
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
                enabled: pad.canConfirm
                focusPolicy: Qt.NoFocus
                onClicked: pad.confirm()
            }
        }
    }
}
