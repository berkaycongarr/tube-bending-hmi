import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

// Program adı girme penceresi. Ad şimdilik bilgisayar klavyesiyle yazılır;
// dokunmatik harf klavyesi ayrı bir adımda eklenecek.
// Ad yazılırken denetlenir: kullanılamayacak bir adla KAYDET'e basılamaz.
T.Popup {
    id: dialog

    required property ProgramStore store
    property string title: qsTr("Programı kaydet")
    property string initialName

    signal nameAccepted(string name)
    signal cancelled()

    // Yazılan adın sorunu (boş: sorun yok)
    readonly property string error: dialog.store.nameError(input.text)

    property bool done: false

    function accept() {
        if (dialog.error.length > 0)
            return
        dialog.done = true
        dialog.close()
    }

    // Karar, pencere kapandıktan sonra bildirilir (bkz. ConfirmDialog).
    onAboutToShow: dialog.done = false
    onOpened: {
        input.text = dialog.initialName
        input.selectAll()
        input.forceActiveFocus()
    }
    onClosed: {
        if (dialog.done)
            dialog.nameAccepted(input.text)
        else
            dialog.cancelled()
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
        spacing: 10

        Text {
            text: dialog.title
            font.pixelSize: Theme.fontTitle
            font.bold: true
            color: Theme.text
        }

        Text {
            text: qsTr("Program adı")
            font.pixelSize: Theme.fontSmall
            font.bold: true
            color: Theme.textMuted
        }

        Rectangle {
            Layout.preferredWidth: 480
            implicitHeight: 56
            radius: Theme.radius
            color: Theme.field
            border.width: 2
            border.color: dialog.error.length > 0 ? Theme.danger
                          : input.activeFocus ? Theme.navSelected : Theme.panelBorder

            TextInput {
                id: input

                objectName: "nameInput"
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: 22
                color: Theme.text
                selectionColor: Theme.navSelected
                selectedTextColor: "white"
                maximumLength: dialog.store.maxNameLength
                selectByMouse: true
                clip: true

                Keys.onReturnPressed: dialog.accept()
                Keys.onEnterPressed: dialog.accept()
            }
        }

        Text {
            objectName: "nameError"
            Layout.preferredWidth: 480
            text: dialog.error.length > 0 ? dialog.error
                                          : qsTr("Bilgisayar klavyesiyle yazın, Enter ile kaydedin.")
            font.pixelSize: Theme.fontSmall
            font.bold: dialog.error.length > 0
            color: dialog.error.length > 0 ? Theme.danger : Theme.textMuted
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.topMargin: 6
            Layout.alignment: Qt.AlignRight
            spacing: 8

            HmiButton {
                objectName: "nameCancel"
                implicitWidth: 140
                implicitHeight: 56
                font.pixelSize: 16
                text: qsTr("İPTAL")
                focusPolicy: Qt.NoFocus
                onClicked: dialog.close()
            }

            HmiButton {
                objectName: "nameOk"
                implicitWidth: 160
                implicitHeight: 56
                font.pixelSize: 16
                text: qsTr("KAYDET")
                accent: Theme.ok
                filled: true
                enabled: dialog.error.length === 0
                focusPolicy: Qt.NoFocus
                onClicked: dialog.accept()
            }
        }
    }
}
