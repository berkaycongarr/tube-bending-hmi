import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

// Onay penceresi: başlık, açıklama ve en fazla üç buton.
//   acceptText   asıl işlem (ör. "KAYDET", "SİL")          → accepted()
//   discardText  ikinci seçenek (ör. "KAYDETME"); boşsa yok → discarded()
//   rejectText   vazgeç (ör. "İPTAL"); boşsa yok           → rejected()
// Yalnızca bilgi vermek için: acceptText "TAMAM", diğer ikisi boş.
T.Popup {
    id: dialog

    property string title
    property string message
    property string acceptText: qsTr("TAMAM")
    property string discardText
    property string rejectText: qsTr("İPTAL")
    property color acceptAccent: Theme.ok

    signal accepted()
    signal discarded()
    signal rejected()

    // Hangi butona basıldı? 0: hiçbiri (Escape), 1: asıl işlem, 2: ikinci seçenek.
    property int choice: 0

    function answer(button: int) {
        dialog.choice = button
        dialog.close()
    }

    // Karar, pencere kapandıktan sonra bildirilir: kararı alan kod hemen yeni bir
    // pencere (ör. bir hata mesajı) açabilsin.
    onAboutToShow: dialog.choice = 0
    onClosed: {
        if (dialog.choice === 1)
            dialog.accepted()
        else if (dialog.choice === 2)
            dialog.discarded()
        else
            dialog.rejected()
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
    padding: 24
    closePolicy: T.Popup.CloseOnEscape

    T.Overlay.modal: Rectangle {
        color: "#73000000"
    }

    background: Rectangle {
        radius: 10
        color: Theme.panel
        border.color: Theme.panelBorder
    }

    contentItem: ColumnLayout {
        spacing: 12

        Text {
            objectName: "confirmTitle"
            Layout.maximumWidth: 520
            text: dialog.title
            font.pixelSize: Theme.fontTitle
            font.bold: true
            color: Theme.text
            wrapMode: Text.WordWrap
        }

        Text {
            objectName: "confirmMessage"
            Layout.preferredWidth: 480
            text: dialog.message
            font.pixelSize: Theme.fontNormal
            color: Theme.text
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.topMargin: 8
            Layout.alignment: Qt.AlignRight
            spacing: 8

            HmiButton {
                objectName: "confirmReject"
                visible: dialog.rejectText.length > 0
                implicitWidth: 140
                implicitHeight: 56
                font.pixelSize: 16
                text: dialog.rejectText
                onClicked: dialog.answer(0)
            }

            HmiButton {
                objectName: "confirmDiscard"
                visible: dialog.discardText.length > 0
                implicitWidth: 150
                implicitHeight: 56
                font.pixelSize: 16
                text: dialog.discardText
                onClicked: dialog.answer(2)
            }

            HmiButton {
                objectName: "confirmAccept"
                implicitWidth: 160
                implicitHeight: 56
                font.pixelSize: 16
                text: dialog.acceptText
                accent: dialog.acceptAccent
                filled: true
                onClicked: dialog.answer(1)
            }
        }
    }
}
