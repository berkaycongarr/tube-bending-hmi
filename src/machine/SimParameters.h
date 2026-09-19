#pragma once

// Sanal makinenin tüm ayarları tek yerde.
// Değerler şimdilik tahmini; müşteriden gerçek değerler gelince burası güncellenecek.

// Bir eksenin ayarları. Birim: X için mm ve mm/sn, B ve A için derece ve derece/sn.
struct AxisParameters
{
    double minPosition;    // yazılım limiti, alt
    double maxPosition;    // yazılım limiti, üst
    double startPosition;  // açılışta eksenin durduğu yer
    double homePosition;   // referans noktası: referans bulununca eksene yazılan değer
    double homingFast;     // referans arama hızı, uzaktayken
    double homingSlow;     // referans arama hızı, yaklaşınca
    double homingSlowZone; // referansa bu kadar kala yavaşla
    double jogSlow;        // jog hızı, yavaş
    double jogFast;        // jog hızı, hızlı
    double moveSpeed;      // konuma gitme hızı
};

namespace SimParameters {

// X'in referansı öbür uçta: fotoğraflarda X, referans ararken artıyordu.
//                                      min     max  başlangıç  referans  ref.hızlı  ref.yavaş  yavaşla  jog.yavaş  jog.hızlı  konumlama
inline constexpr AxisParameters X = {    0.0, 3000.0,  1693.35,   3000.0,     400.0,      40.0,    40.0,      25.0,     150.0,      400.0 };
inline constexpr AxisParameters B = {    0.0,  190.0,     37.5,      0.0,      90.0,      12.0,    12.0,       5.0,      30.0,       45.0 };
inline constexpr AxisParameters A = { -360.0,  360.0,     90.0,      0.0,      90.0,      12.0,    12.0,      10.0,      60.0,       90.0 };

inline constexpr int TickIntervalMs = 20;   // döngü aralığı: saniyede 50 tur
inline constexpr double LatchSeconds = 0.5; // referans noktasında bekleme süresi (sn)
inline constexpr int JogWatchdogMs = 300;   // bu süre "hâlâ basılı" gelmezse jog durur

// Hidrolik
inline constexpr double NominalPressure = 120.0;    // çalışma basıncı (bar)
inline constexpr double PumpStartSeconds = 1.5;     // pompa çalışınca basıncın oluşma süresi
inline constexpr double PumpStopSeconds = 1.0;      // pompa durunca basıncın düşme süresi
inline constexpr double ClampTravelSeconds = 0.8;   // mengene kapanma / açılma süresi
inline constexpr double MandrelTravelSeconds = 1.0; // malafa ileri / geri gitme süresi
inline constexpr double ColletTravelSeconds = 0.5;  // pens kapanma / açılma süresi

} // namespace SimParameters
