pragma Singleton
import QtQuick

// Renkler ve ölçüler tek yerde. Değiştirmek gerekirse yalnızca burası değişir.
// Endüstriyel ekran standardı ISA-101'in önerdiği gibi zemin gri tutulur;
// renk yalnızca bir anlam taşıdığında (hazır, devam ediyor, stop) kullanılır.
QtObject {
    // Zemin ve paneller
    readonly property color background: "#dcdfe3"
    readonly property color panel: "#f2f3f5"
    readonly property color panelBorder: "#c3c8cf"
    readonly property color text: "#1c2229"
    readonly property color textMuted: "#5a6470"

    // Durum renkleri
    readonly property color ok: "#2e7d32"      // hazır, referans tamam
    readonly property color active: "#c77800"  // devam eden işlem
    readonly property color danger: "#c62828"  // stop, alarm
    readonly property color idle: "#8b949e"    // bekliyor, referanssız

    // Butonlar
    readonly property color buttonFace: "#e8eaed"
    readonly property color buttonDown: "#cdd2d8"

    // Ölçüler
    readonly property int radius: 6
    readonly property int gap: 12
    readonly property int fontSmall: 14
    readonly property int fontNormal: 16
    readonly property int fontTitle: 22
    readonly property int fontLarge: 26
}
