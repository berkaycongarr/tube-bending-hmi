import QtQuick

// Push buton mantığıyla jog: basılı tuttukça eksen hareket eder, bırakınca durur.
// Buton basılıyken makineye 100 ms'de bir "hâlâ basılı" haberi gönderilir.
// Makine bu haberi alamazsa ekseni kendisi durdurur (bekçi zamanlayıcı).
HmiButton {
    id: jog

    required property Machine machine
    required property Axis axis
    required property int direction // -1: geri, +1: ileri
    property bool fast: false

    // Parmak butonun üstündeyken ve pencere öndeyken "basılı" sayılır.
    readonly property bool holding: pressed && Window.active

    text: direction > 0 ? "+" : "−"
    font.pixelSize: 36

    // Referans ararken ya da eksen o yöndeki limite dayanmışken kullanılamaz.
    enabled: machine.state !== Machine.Homing
             && !(direction > 0 ? axis.atMaxLimit : axis.atMinLimit)

    // Geri bildirim: buton, eksen gerçekten hareket ediyorsa turuncu dolar.
    // Basılı olduğu halde eksen durmuşsa (STOP, limit) dolmaz.
    filled: holding && axis.moving
    accent: filled ? Theme.active : Theme.text

    onHoldingChanged: {
        if (holding)
            machine.startJog(axis, direction, fast)
        else
            machine.stopJog(axis)
    }

    Timer {
        interval: 100
        repeat: true
        running: jog.holding
        onTriggered: jog.machine.keepJogAlive(jog.axis)
    }
}
