#pragma once

// Sanal makinenin tüm ayarları tek yerde.
// Değerler şimdilik tahmini; müşteriden gerçek değerler gelince burası güncellenecek.

// Bir eksenin ayarları. Birim: X ve Y için mm ve mm/sn, B ve A için derece ve derece/sn.
// Limitler, jog ve konumlama hızları varsayılandır: ayarcı AYARLAR sayfasından değiştirir.
// Limitler yalnızca daraltılabilir (buradaki limitler eksenin yoludur); hızlar maxSpeed'i
// aşamaz. Referans hızları ve referans noktası makineyi kuranın ayarıdır, ekranda yoktur.
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
    double maxSpeed;       // eksenin çıkabileceği en yüksek hız
};

namespace SimParameters {

// X'in referansı öbür uçta: fotoğraflarda X, referans ararken artıyordu.
// Y (öteleme) bir varsayımdır: fotoğraflarda etiketi okunmuyor. Müşterinin tablosundaki
// ÖTELEME (mm) sütununun ekseni olduğunu düşünüyoruz; aralık ve hızlar demoda sorulacak.
//                                      min     max  başlangıç  referans  ref.hızlı  ref.yavaş  yavaşla  jog.yavaş  jog.hızlı  konumlama  en yüksek
inline constexpr AxisParameters X = {    0.0, 3000.0,  1693.35,   3000.0,     400.0,      40.0,    40.0,      25.0,     150.0,      400.0,     600.0 };
inline constexpr AxisParameters B = {    0.0,  190.0,     37.5,      0.0,      90.0,      12.0,    12.0,       5.0,      30.0,       45.0,      90.0 };
inline constexpr AxisParameters A = { -360.0,  360.0,     90.0,      0.0,      90.0,      12.0,    12.0,      10.0,      60.0,       90.0,     180.0 };
inline constexpr AxisParameters Y = {    0.0,  150.0,     42.0,      0.0,      30.0,       5.0,     5.0,       5.0,      25.0,       40.0,      60.0 };

// Alt ve üst limit arasında en az bu kadar yol kalmalı (mm ya da derece).
inline constexpr double MinimumLimitSpan = 10.0;

// Üretim döngüsü. Bu değerler de varsayım; demoda müşteriye sorulacak.
// (Malafalı büküm ve bükümde ilerle kalıbın ayarıdır: KALIPLAR sayfasından gelir.)
inline constexpr double LoadPositionX = 500.0; // boru alma konumu varsayılanı (AYARLAR'dan değişir)

// Döngünün süreleri. Bunlar varsayılanlar: ayarcı ZAMANLAR sayfasından değiştirir,
// değişen değerler makinenin belleğinde (sanal makinede makine.ini) saklanır.
// Aralıklar ve açıklamalar SimMachine.cpp'de (defineTimers).
inline constexpr double ClampDwellSeconds = 0.2;      // mengene kapanınca, büküme başlamadan önce
inline constexpr double BendDwellSeconds = 0.3;       // büküm açısında, mengene açılmadan önce
inline constexpr double StepPauseSeconds = 0.3;       // adımlar arasında (otomatik çalışmada)
inline constexpr double MoveTimeoutSeconds = 45.0;    // eksen hareketi bu sürede bitmezse arıza
inline constexpr double ActuatorTimeoutSeconds = 8.0; // silindir bu sürede yerine gitmezse arıza

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
