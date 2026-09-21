// Liste satırları ve küçük bileşenler "page" ve "list" kimliklerine güvenle erişebilsin.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// KALIPLAR sayfası: makinede kullanılabilen kalıplar ve şu an takılı olanı.
// Müşterinin ekranındaki "AKTİF KALIP" bilgileri (açıklama, kalıp yarıçapı,
// MALAFALI BÜK, BÜKÜMDE İLERLE) burada tutulur ve düzenlenir.
// Takılı kalıp makinedeki fiziksel kalıptır: değiştirilince buradan işaretlenir.
Rectangle {
    id: page

    required property DieLibrary dies
    required property Machine machine

    // Seçili kalıbın adı (boş: seçim yok). Satır numarası yerine ad tutulur:
    // liste sıralı olduğu için ekleme ve düzeltmede satırlar yer değiştirebilir.
    property string selectedName: ""

    readonly property bool hasSelection: page.selectedName.length > 0
    readonly property bool selectedIsActive: page.hasSelection && page.selectedName === page.dies.activeName
    // Döngü sürerken takılı kalıp değişmez: makine o kalıbın bilgileriyle çalışıyor.
    readonly property bool cycleActive: page.machine.cycleState !== Machine.CycleStopped

    // Seçili satırda ne yapılamıyor, neden?
    readonly property string actionHint: {
        if (!page.hasSelection)
            return qsTr("Bir kalıba dokunarak seçin; iki kez dokunmak düzenler.")
        if (page.selectedIsActive)
            return page.cycleActive ? qsTr("Takılı kalıp döngü sürerken düzenlenemez ve silinemez.")
                                    : qsTr("Takılı kalıp silinemez: önce başka bir kalıbı takılı yapın.")
        if (page.cycleActive)
            return qsTr("Döngü sürerken takılı kalıp değiştirilemez.")
        return ""
    }

    function selectedRow(): int {
        return page.dies.indexOf(page.selectedName)
    }

    function editSelected() {
        const row = page.selectedRow()
        if (row >= 0 && !(page.selectedIsActive && page.cycleActive))
            dieDialog.openEdit(row)
    }

    function formatMm(value: real): string {
        return value.toFixed(2) + " mm"
    }

    // Açılışta takılı kalıp seçili gelir.
    Component.onCompleted: page.selectedName = page.dies.activeName

    radius: Theme.radius
    color: Theme.panel
    border.color: Theme.panelBorder

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // ---------------- Sol: kalıp listesi ----------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: qsTr("Kalıplar")
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                    color: Theme.text
                }

                Text {
                    objectName: "dieCount"
                    text: qsTr("%1 kalıp").arg(page.dies.count)
                    font.pixelSize: Theme.fontNormal
                    color: Theme.textMuted
                }

                // Kalıpların durduğu dosya: yedeklenebilir, başka makineye kopyalanabilir.
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: page.dies.file
                    font.pixelSize: 12
                    color: Theme.textMuted
                    elide: Text.ElideMiddle
                }
            }

            // Açılışta dosyada sorun çıktıysa (bozuk dosya yedeklendi vb.)
            Rectangle {
                objectName: "dieLoadWarning"
                Layout.fillWidth: true
                visible: page.dies.loadWarning.length > 0
                implicitHeight: warningText.implicitHeight + 16
                radius: Theme.radius
                color: "#1ac62828"
                border.color: Theme.danger

                Text {
                    id: warningText

                    anchors.fill: parent
                    anchors.margins: 8
                    text: page.dies.loadWarning
                    font.pixelSize: Theme.fontSmall
                    font.bold: true
                    color: Theme.danger
                    wrapMode: Text.WordWrap
                }
            }

            // Tablo başlığı
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 44
                radius: Theme.radius
                color: Theme.buttonFace

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 16
                    spacing: 8

                    HeaderText {
                        Layout.fillWidth: true
                        text: qsTr("AÇIKLAMA")
                    }

                    HeaderText {
                        Layout.preferredWidth: 76
                        horizontalAlignment: Text.AlignRight
                        text: qsTr("KALIP\nRADIUS")
                    }

                    HeaderText {
                        Layout.preferredWidth: 66
                        horizontalAlignment: Text.AlignRight
                        text: qsTr("BORU\nÇAPI")
                    }

                    HeaderText {
                        Layout.preferredWidth: 64
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTr("MALAFALI\nBÜK")
                    }

                    HeaderText {
                        Layout.preferredWidth: 64
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTr("BÜKÜMDE\nİLERLE")
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: list

                    objectName: "dieList"
                    anchors.fill: parent
                    anchors.rightMargin: 10
                    clip: true
                    spacing: 4
                    boundsBehavior: Flickable.StopAtBounds
                    model: page.dies

                    delegate: Rectangle {
                        id: row

                        required property string name
                        required property real dieRadius
                        required property real tubeDiameter
                        required property bool mandrel
                        required property bool feedDuringBend
                        required property bool active

                        readonly property bool selected: page.selectedName === row.name

                        objectName: "dieRow:" + row.name
                        width: list.width
                        height: 52
                        radius: Theme.radius
                        color: row.selected ? Theme.selection : Theme.field
                        border.width: row.selected ? 2 : 1
                        border.color: row.selected ? Theme.navSelected : Theme.panelBorder

                        TapHandler {
                            onTapped: page.selectedName = row.name
                            onDoubleTapped: {
                                page.selectedName = row.name
                                page.editSelected()
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 6
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                // Ad kendi boyuna kadar genişler; yer yetmezse önce o kısalır.
                                // Arta kalan boşluk satırın sonunda kalır.
                                Text {
                                    objectName: "dieRowName"
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: implicitWidth
                                    text: row.name
                                    font.pixelSize: Theme.fontNormal
                                    font.bold: true
                                    color: Theme.text
                                    elide: Text.ElideRight
                                }

                                // Makineye takılı kalıp
                                Rectangle {
                                    visible: row.active
                                    implicitWidth: activeTag.implicitWidth + 16
                                    implicitHeight: 24
                                    radius: 12
                                    color: Theme.ok

                                    Text {
                                        id: activeTag

                                        anchors.centerIn: parent
                                        text: qsTr("TAKILI")
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: "white"
                                    }
                                }
                            }

                            CellText {
                                Layout.preferredWidth: 76
                                horizontalAlignment: Text.AlignRight
                                text: row.dieRadius.toFixed(2)
                            }

                            CellText {
                                Layout.preferredWidth: 66
                                horizontalAlignment: Text.AlignRight
                                text: row.tubeDiameter.toFixed(2)
                            }

                            CellText {
                                Layout.preferredWidth: 64
                                horizontalAlignment: Text.AlignHCenter
                                text: row.mandrel ? "✓" : "—"
                                color: row.mandrel ? Theme.text : Theme.idle
                            }

                            CellText {
                                Layout.preferredWidth: 64
                                horizontalAlignment: Text.AlignHCenter
                                text: row.feedDuringBend ? "✓" : "—"
                                color: row.feedDuringBend ? Theme.text : Theme.idle
                            }
                        }
                    }
                }

                // Kaydırma göstergesi: liste sığmıyorsa nerede olunduğunu gösterir.
                Rectangle {
                    anchors.left: list.right
                    anchors.leftMargin: 3
                    y: list.visibleArea.yPosition * list.height
                    width: 4
                    height: list.visibleArea.heightRatio * list.height
                    radius: 2
                    color: Theme.idle
                    visible: list.contentHeight > list.height
                }

                Text {
                    objectName: "dieEmpty"
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - 40)
                    visible: page.dies.count === 0
                    text: qsTr("Kayıtlı kalıp yok. YENİ ile ekleyin.")
                    font.pixelSize: Theme.fontNormal
                    color: Theme.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }

            // Son işlem başarısızsa nedeni; değilse seçili satır için ipucu
            Text {
                objectName: "dieHint"
                Layout.fillWidth: true
                text: page.dies.lastError.length > 0 ? page.dies.lastError : page.actionHint
                font.pixelSize: Theme.fontSmall
                font.bold: page.dies.lastError.length > 0
                color: page.dies.lastError.length > 0 ? Theme.danger : Theme.textMuted
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                HmiButton {
                    objectName: "dieNew"
                    implicitWidth: 96
                    implicitHeight: 56
                    font.pixelSize: 16
                    text: qsTr("YENİ")
                    onClicked: dieDialog.openNew()
                }

                HmiButton {
                    objectName: "dieEdit"
                    implicitWidth: 120
                    implicitHeight: 56
                    font.pixelSize: 16
                    text: qsTr("DÜZENLE")
                    enabled: page.hasSelection && !(page.selectedIsActive && page.cycleActive)
                    onClicked: page.editSelected()
                }

                HmiButton {
                    objectName: "dieRemove"
                    implicitWidth: 84
                    implicitHeight: 56
                    font.pixelSize: 16
                    text: qsTr("SİL")
                    accent: Theme.danger
                    enabled: page.hasSelection && !page.selectedIsActive
                    onClicked: {
                        removeConfirm.message = qsTr("«%1» kalıp listesinden kaldırılacak. "
                                                     + "Bu işlem geri alınamaz.").arg(page.selectedName)
                        removeConfirm.open()
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                HmiButton {
                    objectName: "dieActivate"
                    implicitWidth: 200
                    implicitHeight: 56
                    font.pixelSize: 16
                    text: qsTr("TAKILI KALIP YAP")
                    accent: Theme.ok
                    filled: true
                    enabled: page.hasSelection && !page.selectedIsActive && !page.cycleActive
                    onClicked: {
                        activateConfirm.message = qsTr("«%1» takılı kalıp olarak işaretlenecek. Makinedeki "
                                                       + "kalıbın gerçekten bu olduğundan emin olun: "
                                                       + "üretim bu kalıbın bilgileriyle yapılır.")
                                                  .arg(page.selectedName)
                        activateConfirm.open()
                    }
                }
            }
        }

        // ---------------- Sağ: takılı kalıp ----------------
        Rectangle {
            objectName: "activeDieCard"
            Layout.fillWidth: false
            Layout.preferredWidth: 236
            Layout.fillHeight: true
            radius: Theme.radius
            color: Theme.field
            border.width: 2
            border.color: page.dies.hasActive ? Theme.ok : Theme.active

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                Text {
                    text: qsTr("TAKILI KALIP")
                    font.pixelSize: 13
                    font.bold: true
                    color: page.dies.hasActive ? Theme.ok : Theme.activeText
                }

                Text {
                    objectName: "activeDieName"
                    Layout.fillWidth: true
                    text: page.dies.hasActive ? page.dies.activeName : qsTr("Seçilmemiş")
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                    color: page.dies.hasActive ? Theme.text : Theme.activeText
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 15
                    elide: Text.ElideRight
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: page.dies.hasActive
                    spacing: 6

                    InfoLine {
                        objectName: "activeDieRadius"
                        caption: qsTr("Kalıp yarıçapı")
                        value: page.formatMm(page.dies.activeRadius)
                    }

                    InfoLine {
                        caption: qsTr("Boru çapı")
                        value: page.formatMm(page.dies.activeTubeDiameter)
                    }

                    InfoLine {
                        caption: qsTr("Malafalı büküm")
                        value: page.dies.activeMandrel ? qsTr("Evet") : qsTr("Hayır")
                    }

                    InfoLine {
                        caption: qsTr("Bükümde ilerle")
                        value: page.dies.activeFeedDuringBend ? qsTr("Evet") : qsTr("Hayır")
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    text: page.dies.hasActive
                          ? qsTr("Makinede duran kalıp. Kalıp değiştirildiğinde listeden seçip "
                                 + "TAKILI KALIP YAP'a basın.")
                          : qsTr("Makinede hangi kalıbın takılı olduğunu listeden seçip "
                                 + "TAKILI KALIP YAP ile işaretleyin.")
                    font.pixelSize: 13
                    color: Theme.textMuted
                    wrapMode: Text.WordWrap
                }

                Item {
                    Layout.fillHeight: true
                }
            }
        }
    }

    DieDialog {
        id: dieDialog

        dies: page.dies
        onSaved: name => page.selectedName = name
    }

    ConfirmDialog {
        id: removeConfirm

        title: qsTr("Kalıp silinsin mi?")
        acceptText: qsTr("SİL")
        acceptAccent: Theme.danger
        onAccepted: {
            if (page.dies.remove(page.selectedRow()))
                page.selectedName = ""
        }
    }

    ConfirmDialog {
        id: activateConfirm

        title: qsTr("Takılı kalıbı değiştir")
        acceptText: qsTr("TAKILI YAP")
        onAccepted: page.dies.setActive(page.selectedRow())
    }

    // Tablo başlığındaki sütun adı
    component HeaderText: Text {
        font.pixelSize: 12
        font.bold: true
        color: Theme.textMuted
        lineHeight: 0.9
    }

    // Tablo hücresi
    component CellText: Text {
        font.pixelSize: Theme.fontNormal
        font.bold: true
        color: Theme.text
    }

    // Takılı kalıp kartındaki bir satır: solda başlık, sağda değer.
    component InfoLine: RowLayout {
        id: line

        required property string caption
        required property string value

        Layout.fillWidth: true
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: line.caption
            font.pixelSize: Theme.fontSmall
            color: Theme.textMuted
            elide: Text.ElideRight
        }

        Text {
            objectName: "infoLineValue"
            text: line.value
            font.pixelSize: Theme.fontSmall
            font.bold: true
            color: Theme.text
        }
    }
}
