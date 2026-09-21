import QtQuick
import QtQuick.Layouts

// Ayar kilidi şeridi: makinenin ayarlarını değiştirmek (ya da IO TEST'te çıkış sürmek)
// için ayarcı şifresi. AYARLAR, ZAMANLAR ve IO TEST sayfalarının üstünde durur; kilidin
// durumunu ve kalan süreyi gösterir, KİLİDİ AÇ / KİLİTLE butonu vardır.
//
// Sayfa bir değeri değiştirmek istediğinde request("iş") çağırır: kilit açıksa
// granted("iş") hemen gelir; kapalıysa önce şifre sorulur, doğruysa granted gelir.
// Böylece değerleri herkes görür, değiştirmek şifreyle olur.
Rectangle {
    id: bar

    required property AccessControl access

    // Şifre doğru girilince yapılacak iş (sayfanın verdiği ad)
    property string pendingTag: ""

    // Şifrenin ne için sorulduğu: kilitliyken şeritte ve şifre sorulurken yazar (sayfaya göre).
    property string lockedText: qsTr("Kilitli · değerleri değiştirmek için ayarcı şifresi gerekir")
    property string pinNote: qsTr("Makinenin ayarlarını değiştirmek için şifreyi girin.")

    signal granted(string tag)

    function request(tag: string) {
        if (bar.access.unlocked) {
            bar.access.keepAlive()
            bar.granted(tag)
            return
        }
        bar.pendingTag = tag
        pinPad.open()
    }

    // 600 → "10:00"
    function clock(seconds: int): string {
        const minutes = Math.floor(seconds / 60)
        const rest = seconds % 60
        return minutes + ":" + (rest < 10 ? "0" : "") + rest
    }

    implicitHeight: 56
    radius: Theme.radius
    color: bar.access.unlocked ? "#142e7d32" : Theme.field
    border.width: bar.access.unlocked ? 2 : 1
    border.color: bar.access.unlocked ? Theme.ok : Theme.panelBorder

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 6
        spacing: 10

        Text {
            objectName: "lockState"
            Layout.fillWidth: true
            text: bar.access.unlocked
                  ? qsTr("Ayar açık · %1 sonra kendiliğinden kilitlenir").arg(bar.clock(bar.access.remainingSeconds))
                  : bar.lockedText
            font.pixelSize: 15
            font.bold: true
            color: bar.access.unlocked ? Theme.ok : Theme.textMuted
            elide: Text.ElideRight
        }

        HmiButton {
            objectName: "lockButton"
            implicitWidth: 150
            implicitHeight: 44
            padding: 6
            font.pixelSize: 15
            text: bar.access.unlocked ? qsTr("KİLİTLE") : qsTr("KİLİDİ AÇ")
            accent: bar.access.unlocked ? Theme.text : Theme.ok
            onClicked: {
                if (bar.access.unlocked)
                    bar.access.lock()
                else
                    bar.request("")
            }
        }
    }

    // Şifre tuş takımı: rakamlar görünmez. Yanlışsa açık kalır ve söyler.
    NumericKeypad {
        id: pinPad

        secret: true
        title: qsTr("Ayarcı şifresi")
        note: bar.pinNote
        secretMinimum: bar.access.minimumPinLength
        secretMaximum: bar.access.maximumPinLength
        onSecretEntered: text => {
            if (bar.access.unlock(text)) {
                const tag = bar.pendingTag
                bar.pendingTag = ""
                pinPad.close()
                if (tag.length > 0)
                    bar.granted(tag)
            } else {
                // Önce yazılan silinir, sonra hata yazılır (yazı değişince hata kalkar).
                pinPad.entry = ""
                pinPad.errorText = qsTr("Şifre yanlış")
            }
        }
    }
}
