// Sekme butonu bu dosyadaki "tabs" kimliğine güvenle erişebilsin.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

// İki sekme: LİSTE (program tablosu) ve SİMÜLASYON (parçanın çizimi). Müşterinin
// ekranında da tablonun üstünde bu iki sekme var, genişliği ikiye bölerek.
// Seçili sekme koyu dolu görünür (sol menüdeki seçili sayfa gibi).
Rectangle {
    id: tabs

    // 0: LİSTE, 1: SİMÜLASYON
    property int currentIndex: 0

    implicitHeight: 38
    radius: Theme.radius
    color: Theme.buttonFace
    border.color: Theme.panelBorder

    RowLayout {
        anchors.fill: parent
        anchors.margins: 3
        spacing: 3

        Tab {
            objectName: "tabList"
            index: 0
            text: qsTr("LİSTE")
        }

        Tab {
            objectName: "tabSimulation"
            index: 1
            text: qsTr("SİMÜLASYON")
        }
    }

    component Tab: T.Button {
        id: tab

        required property int index
        readonly property bool selected: tabs.currentIndex === tab.index

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.fillHeight: true
        font.pixelSize: 15
        font.bold: true
        onClicked: tabs.currentIndex = tab.index

        contentItem: Text {
            text: tab.text
            font: tab.font
            color: tab.selected ? "white" : Theme.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        background: Rectangle {
            radius: Theme.radius - 2
            color: tab.selected ? Theme.navSelected : (tab.down ? Theme.buttonDown : "transparent")
        }
    }
}
