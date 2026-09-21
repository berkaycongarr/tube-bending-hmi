// Liste satırları "page", "lockBar" ve listelerin kimliklerine güvenle erişebilsin.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// IO TEST sayfası: makinenin girişleri ve çıkışları, canlı (müşterinin menüsündeki IO TEST).
//   girişler: sensörler ve şalterler (mengene kapalı, basınç var, referans sensörü...)
//   çıkışlar: pompa motoru ve valfler
// Bakımcı bir sensörü tetikleyip lambasının yandığını görür; bir çıkışı sürüp silindirin
// gittiğini ve sensörlerin değiştiğini izler. Girişleri herkes görür. Çıkış sürmek ayarcı
// şifresiyle ve yalnızca döngü dururken olur; makinenin kilitleri burada da geçerlidir
// (ör. basınç yokken valf sürülmez). Çıkış neden sürülemiyorsa satırı yazar.
Rectangle {
    id: page

    required property Machine machine
    required property AccessControl access

    // 1 olan satırın zemini: hafif yeşil (durumu asıl lamba söyler)
    readonly property color activeTint: "#1a2e7d32"

    // Şifre soruldu ve doğruysa (ya da kilit zaten açıksa) istenen iş yapılır.
    // "set:Q0.1:1" → Q0.1'i 1 yap. İstenen değer butona basıldığı anda belirlenir.
    function run(tag: string) {
        const parts = tag.split(":")
        if (parts.length === 3 && parts[0] === "set")
            page.machine.setOutput(parts[1], parts[2] === "1")
    }

    radius: Theme.radius
    color: Theme.panel
    border.color: Theme.panelBorder

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: qsTr("IO Test")
                font.pixelSize: Theme.fontTitle
                font.bold: true
                color: Theme.text
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Makinenin girişleri ve çıkışları, canlı")
                font.pixelSize: Theme.fontNormal
                color: Theme.textMuted
                elide: Text.ElideRight
            }
        }

        LockBar {
            id: lockBar

            Layout.fillWidth: true
            access: page.access
            lockedText: qsTr("Kilitli · çıkışları sürmek için ayarcı şifresi gerekir")
            pinNote: qsTr("Çıkışları sürmek için şifreyi girin.")
            onGranted: tag => page.run(tag)
        }

        RowLayout {
            id: panels

            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            // ---------------- Girişler: yalnızca gösterilir ----------------
            // Dar ekranda (1024 px) en az 336 px: en uzun ad ("X REFERANS SENSÖRÜ") sığsın.
            Rectangle {
                Layout.preferredWidth: Math.max(336, Math.round((panels.width - panels.spacing) * 0.42))
                Layout.fillHeight: true
                radius: Theme.radius
                color: Theme.field
                border.color: Theme.panelBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    PanelTitle {
                        title: qsTr("GİRİŞLER")
                        hint: qsTr("sensörler ve şalterler")
                    }

                    ListView {
                        id: inputList

                        // Satır boyu listeye göre: girişlerin hepsi kaydırmadan sığsın. Liste
                        // uzunsa (gerçek makinede) satırlar 26 px'de kalır, liste kaydırılır.
                        readonly property real rowHeight: inputList.count > 0
                                                          ? Math.max(26, Math.min(36, Math.floor(inputList.height / inputList.count)))
                                                          : 36

                        objectName: "inputList"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: page.machine.inputs

                        delegate: Rectangle {
                            id: inputRow

                            required property string address
                            required property string name
                            required property bool active

                            objectName: "input:" + inputRow.address
                            width: inputList.width
                            height: inputList.rowHeight
                            color: inputRow.active ? page.activeTint : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 10
                                spacing: 8

                                Led {
                                    lit: inputRow.active
                                }

                                AddressText {
                                    text: inputRow.address
                                }

                                Text {
                                    objectName: "ioName"
                                    Layout.fillWidth: true
                                    text: inputRow.name
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: Theme.text
                                    elide: Text.ElideRight
                                }

                                StateText {
                                    active: inputRow.active
                                }
                            }

                            // Satırları ayıran ince çizgi
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: Theme.selection
                            }
                        }
                    }
                }
            }

            // ---------------- Çıkışlar: ayarcı şifresiyle sürülür ----------------
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radius
                color: Theme.field
                border.color: Theme.panelBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    PanelTitle {
                        title: qsTr("ÇIKIŞLAR")
                        hint: qsTr("pompa ve valfler")
                    }

                    ListView {
                        id: outputList

                        objectName: "outputList"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        boundsBehavior: Flickable.StopAtBounds
                        model: page.machine.outputs

                        // Bir çıkış: lamba, adres, ad ve 1/0'ın anlamı (ya da neden
                        // sürülemediği) ve butonu. Buton yapılacak işi söyler: çıkış 0 ise
                        // AKTİF ET (1 yap), 1 ise PASİF ET (0 yap).
                        delegate: Rectangle {
                            id: outputRow

                            required property string address
                            required property string name
                            required property string note
                            required property bool active
                            required property string lock

                            readonly property bool locked: outputRow.lock.length > 0

                            objectName: "output:" + outputRow.address
                            width: outputList.width
                            height: 64
                            radius: Theme.radius
                            color: outputRow.active ? page.activeTint : Theme.field
                            border.color: outputRow.active ? Theme.ok : Theme.panelBorder

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                spacing: 8

                                Led {
                                    lit: outputRow.active
                                }

                                AddressText {
                                    text: outputRow.address
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        objectName: "ioName"
                                        Layout.fillWidth: true
                                        text: outputRow.name
                                        font.pixelSize: 15
                                        font.bold: true
                                        color: Theme.text
                                        elide: Text.ElideRight
                                    }

                                    // Kilitliyse nedeni turuncu, değilse 1 ve 0'ın anlamı.
                                    Text {
                                        objectName: "ioNote"
                                        Layout.fillWidth: true
                                        text: outputRow.locked ? outputRow.lock : outputRow.note
                                        font.pixelSize: 13
                                        font.bold: outputRow.locked
                                        color: outputRow.locked ? Theme.activeText : Theme.textMuted
                                        elide: Text.ElideRight
                                    }
                                }

                                HmiButton {
                                    objectName: "ioToggle"
                                    implicitWidth: 96
                                    implicitHeight: 48
                                    padding: 6
                                    font.pixelSize: 15
                                    text: outputRow.active ? qsTr("PASİF ET") : qsTr("AKTİF ET")
                                    enabled: !outputRow.locked
                                    onClicked: lockBar.request("set:" + outputRow.address + ":"
                                                               + (outputRow.active ? "0" : "1"))
                                }
                            }
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: qsTr("1 (yeşil): sinyal var. Çıkış sürmek, HAREKET'teki butonlarla aynı komutu verir: "
                       + "yalnızca döngü dururken olur ve makinenin kilitleri burada da geçerlidir.")
            font.pixelSize: 13
            color: Theme.textMuted
            wrapMode: Text.WordWrap
        }
    }

    // Panel başlığı ve kısa açıklaması
    component PanelTitle: RowLayout {
        id: panelTitle

        required property string title
        required property string hint

        Layout.fillWidth: true
        spacing: 8

        Text {
            text: panelTitle.title
            font.pixelSize: 14
            font.bold: true
            color: Theme.text
        }

        Text {
            Layout.fillWidth: true
            text: panelTitle.hint
            font.pixelSize: 13
            color: Theme.textMuted
            elide: Text.ElideRight
        }
    }

    // Durum lambası: 1 ise dolu yeşil, 0 ise içi boş gri halka (renk görmeyen de ayırt eder).
    component Led: Rectangle {
        id: led

        required property bool lit

        objectName: "ioLed"
        implicitWidth: 16
        implicitHeight: 16
        radius: 8
        color: led.lit ? Theme.ok : "transparent"
        border.width: 2
        border.color: led.lit ? Theme.ok : Theme.idle
    }

    // PLC adresi (ör. I0.2): sabit genişlikte, satırlar alt alta hizalı kalsın.
    component AddressText: Text {
        Layout.preferredWidth: 38
        font.pixelSize: 14
        font.bold: true
        color: Theme.textMuted
    }

    // Girişin durumu: 1 ya da 0 (çıkışta butonun yazısı söyler)
    component StateText: Text {
        id: stateText

        required property bool active

        objectName: "ioState"
        Layout.preferredWidth: 12
        horizontalAlignment: Text.AlignHCenter
        text: stateText.active ? "1" : "0"
        font.pixelSize: 16
        font.bold: true
        color: stateText.active ? Theme.ok : Theme.idle
    }
}
