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

## Eksenler

| Eksen | Görevi | Birim |
|---|---|---|
| X | İlerletme: araba boruyu iter | mm |
| B | Büküm kolu | ° |
| A | Rotasyon: boru kendi ekseninde döner | ° |
| Y | Öteleme (varsayım; görevi, aralığı ve hızları müşteriye sorulacak) | mm |

Referans arama sırası: B → Y → A → X. Tüm değerler `src/machine/SimParameters.h` içinde.

## Mimari

```
Ekran (QML)  →  IMachine (sözleşme)  ←  SimMachine      (demo: sanal makine)
                                     ←  SiemensMachine  (gerçek makine, ileride)
```

Ekran yalnızca `IMachine`'i tanır. Gerçek makineye geçerken ekran kodu değişmez;
`main.cpp`'de oluşturulan makine nesnesi değişir.

Büküm programı (`BendProgram`, reçete) makineden ayrıdır: ekranın verisidir, makineye
geçişte değişmez. Adımların alabileceği değerler makinenin eksen limitlerinden gelir.

## Programlar

Her program `Belgeler\BoruBukme\Programlar` klasöründe ayrı bir `.json` dosyasıdır;
dosyanın adı programın adıdır. Dosyalar kopyalanabilir, başka makineye taşınabilir.
Son açılan program `Belgeler\BoruBukme\ayarlar.ini` içinde tutulur; uygulama açılınca
o program açılır. Klasör boşsa örnek program oraya kaydedilir.

Kaydetme güvenlidir (`QSaveFile`): önce geçici bir dosyaya yazılır, yazma bitince eski
dosyanın yerine geçer. Kaydedilmemiş değişiklik varken başka program açılırsa ya da
uygulama kapatılırsa önce sorulur.

## Klasör yapısı

| Dosya | Görevi |
|---|---|
| `src/main.cpp` | Giriş noktası: makineyi ve programı oluşturur, ekranı yükler |
| `src/machine/Axis.h` | Eksen: konum, hareket, referans, limit ve kilit durumu |
| `src/machine/Actuator.h` | Hidrolik silindir: komut, sensör durumu ve kilit |
| `src/machine/IMachine.h` | Makine sözleşmesi: ekranın tanıdığı tek sınıf |
| `src/machine/SimMachine.*` | Sanal makine (demo) |
| `src/machine/SimParameters.h` | Sanal makinenin ayarları: limitler, hızlar, süreler |
| `src/program/BendProgram.*` | Büküm programı (reçete): komut listesi, açınım boyu, doğrulama, JSON biçimi |
| `src/program/ProgramStore.*` | Program deposu: klasördeki dosyalar, aç / kaydet / sil |
| `qml/Main.qml` | Ana çerçeve: üst şerit, sol menü, sayfalar |
| `qml/ProductionPage.qml` | Üretim sayfası: açık program, üretime hazır mı, program yükleme, referans arama |
| `qml/DesignPage.qml` | Tasarım sayfası: program tablosu, boru ve kalıp, açınım boyu |
| `qml/ProgramTable.qml` | Program tablosu (TASARIM'da düzenlenir, ÜRETİM'de yalnızca gösterir) |
| `qml/ProgramManager.qml` | Program dosya işlemlerinin akışı ve soruları |
| `qml/ProgramsDialog.qml` | Programlar penceresi: liste, AÇ / YENİ / FARKLI KAYDET / SİL |
| `qml/NameDialog.qml` | Program adı girme penceresi |
| `qml/ConfirmDialog.qml` | Onay ve bilgi penceresi |
| `qml/MotionPage.qml` | Hareket sayfası: jog, hedef konuma gitme ve hidrolik |
| `qml/Theme.qml` | Renkler ve ölçüler |
| `qml/HmiButton.qml` | Dokunmatik buton |
| `qml/JogButton.qml` | Push buton mantığıyla jog butonu |
| `qml/NavButton.qml` | Sol menü butonu |
| `qml/ValueField.qml` | Dokununca tuş takımı açan değer alanı |
| `qml/NumericKeypad.qml` | Dokunmatik sayı tuş takımı (aralık denetimli) |
| `qml/PumpControl.qml` | Hidrolik pompa: START/STOP, durum ve basınç |
| `qml/ActuatorButton.qml` | Kalıcı buton mantığıyla silindir kumandası |
| `qml/AxisDisplay.qml` | Eksen konum göstergesi |
