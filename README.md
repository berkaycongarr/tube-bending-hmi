# Boru Bükme Makinesi – Operatör Paneli

CNC boru bükme makinesi için Windows operatör ekranı (HMI). C++ ve Qt 6 (QML) ile yazıldı.

Şu an **simülasyon modunda** çalışır: gerçek makine yerine sanal bir makine (`SimMachine`) kullanılır.

## Gereksinimler

- Qt 6.8 veya üstü (geliştirme ortamı: Qt 6.11.2, MinGW 13.1 64-bit)
- CMake 3.16+ ve Ninja (Qt yükleyicisiyle gelir)

## Derleme ve çalıştırma

1. Qt Creator → **File → Open File or Project…** → `CMakeLists.txt`
2. Kit olarak **Desktop Qt 6.11.2 MinGW 64-bit** seçin → **Configure Project**
3. Sol alttaki ▶ butonu (Ctrl+R)

## Mimari

```
Ekran (QML)  →  IMachine (sözleşme)  ←  SimMachine      (demo: sanal makine)
                                     ←  SiemensMachine  (gerçek makine, ileride)
```

Ekran yalnızca `IMachine`'i tanır. Gerçek makineye geçerken ekran kodu değişmez;
`main.cpp`'de oluşturulan makine nesnesi değişir.

## Klasör yapısı

| Dosya | Görevi |
|---|---|
| `src/main.cpp` | Giriş noktası: makineyi oluşturur, ekranı yükler |
| `src/machine/Axis.h` | Eksen: konum, hareket, referans ve limit durumu |
| `src/machine/IMachine.h` | Makine sözleşmesi: ekranın tanıdığı tek sınıf |
| `src/machine/SimMachine.*` | Sanal makine (demo) |
| `src/machine/SimParameters.h` | Sanal makinenin ayarları: limitler, hızlar, süreler |
| `qml/Main.qml` | Ana çerçeve: üst şerit, sol menü, sayfalar |
| `qml/ProductionPage.qml` | Üretim sayfası (şimdilik referans arama) |
| `qml/MotionPage.qml` | Hareket sayfası: eksenleri elle sürme (jog) |
| `qml/Theme.qml` | Renkler ve ölçüler |
| `qml/HmiButton.qml` | Dokunmatik buton |
| `qml/JogButton.qml` | Push buton mantığıyla jog butonu |
| `qml/NavButton.qml` | Sol menü butonu |
| `qml/AxisDisplay.qml` | Eksen konum göstergesi |
