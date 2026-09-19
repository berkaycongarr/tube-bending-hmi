#pragma once

// Sanal makinenin tüm ayarları tek yerde.
// Değerler şimdilik tahmini; müşteriden gerçek değerler gelince burası güncellenecek.

// Bir eksenin ayarları. Birim: X için mm ve mm/sn, B ve A için derece ve derece/sn.
struct AxisParameters
{
    double minPosition;    // yazılım limiti, alt
    double maxPosition;    // yazılım limiti, üst
    double startPosition;  // açılışta eksenin durduğu yer
    double homingFast;     // referans arama hızı, uzaktayken
    double homingSlow;     // referans arama hızı, yaklaşınca
    double homingSlowZone; // referansa bu kadar kala yavaşla
    double jogSlow;        // jog hızı, yavaş
    double jogFast;        // jog hızı, hızlı
};

namespace SimParameters {

//                                      min     max  başlangıç  ref.hızlı  ref.yavaş  yavaşla  jog.yavaş  jog.hızlı
inline constexpr AxisParameters X = {    0.0, 3000.0,  1693.35,     400.0,      40.0,    40.0,      25.0,     150.0 };
inline constexpr AxisParameters B = {    0.0,  190.0,     37.5,      90.0,      12.0,    12.0,       5.0,      30.0 };
inline constexpr AxisParameters A = { -360.0,  360.0,     90.0,      90.0,      12.0,    12.0,      10.0,      60.0 };

inline constexpr int TickIntervalMs = 20;   // döngü aralığı: saniyede 50 tur
inline constexpr double LatchSeconds = 0.5; // referans noktasında bekleme süresi (sn)
inline constexpr int JogWatchdogMs = 300;   // bu süre "hâlâ basılı" gelmezse jog durur

} // namespace SimParameters
