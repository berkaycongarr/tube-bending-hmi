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

Makinenin ürettiği toplam adet de `ayarlar.ini` içinde tutulur: uygulama kapanınca sıfırlanmaz.

## Üretim döngüsü

Parçanın adımlarını **makine** yürütür; ekran yalnızca tarifi (program adımlarını) gönderir,
START/STOP der ve durumu gösterir. Gerçek makinede bu sıra PLC'nin içindedir: ekran donsa
bile makine parçayı bitirir. `SimMachine` bunu bir PLC adım zinciri gibi uygular
(`beginPhase` komutu verir, `updateCycle` her turda "bu aşama bitti mi?" diye bakar).

Bir parçanın sırası:

1. Araba boru alma konumuna (X = 500 mm), büküm kolu başa (B = 0) gider, malafa geri çekilir
2. Pens açıksa boru beklenir: operatör boruyu takıp pensi kapatır, START'a basar
3. Malafa ileri çıkar
4. Program adımları sırayla işlenir:
   - **İLERLE** (göreli): araba boruyu bu kadar mm ilerletir
   - **BÜK** (mutlak açı): mengene kapanır → kol açıya döner → mengene açılır → kol başa döner.
     Büküm sırasında araba yayı takip eder (yay boyu = kalıp yarıçapı × açı), böylece arabanın
     gittiği toplam yol programın açınım boyuna eşit olur
   - **ROTASYON** (mutlak açı): boru kendi ekseninde döner
5. Malafa geri çekilir, pens açılır: parça biter, üretilen ve toplam adet artar

Ekranda döngü şöyle kullanılır: **BAŞLAT** ve **STOP** üst şeritte, her sayfadan erişilir
(müşterinin ekranında da bu ikili sağ üstte). ÜRETİM sayfasında işlenen adım tabloda turuncu
görünür, altındaki çubuk ilerlemeyi ve durum yazısı makinenin ne beklediğini söyler
("Boruyu takın, pensi kapatın ve BAŞLAT'a basın" gibi). Hidrolik kumandalar da bu sayfadadır:
operatör boruyu takarken pense ulaşmak için sayfa değiştirmez.

Çalışma modu iki türlüdür ve ekrandan seçilir: **OTOMATİK** (BAŞLAT parçanın tamamını işler) ve
**YARI OTOMATİK** (BAŞLAT tek adım işler; program denenirken adımlar tek tek görülür).
Mod, döngü çalışırken değişmez; seçim `ayarlar.ini` içinde saklanır.

Döngü şu durumlarda başlamaz: makine referanssız, pompa durmuş, mengene kapalı ya da boru
beklenirken pens açık. Döngü sırasında elle kumanda (jog, konuma git, silindirler, referans
arama) kilitlidir ve butonlar nedenini yazar. Eksenler, döngü operatörü beklerken de kilitli
kalır: araba oynatılırsa döngü kaldığı yerden yanlış devam eder. Silindirler ise beklerken
serbesttir, çünkü boruyu takmak için pens gerekir. STOP döngüyü keser. Basınç kesilirse ya da bir aşama beklenen sürede
bitmezse döngü arızayla durur; silindirler olduğu gibi kalır — yarıda kalan bir parçada
mengenenin kendiliğinden açılması tehlikelidir, kararı operatör verir.

Varsayımlar (demoda müşteriye sorulacak): boru alma konumu, büküm sırasında ilerleme,
malafalı büküm, adım arası duraklama ve zaman aşımı süreleri, BÜK ile ROTASYON değerlerinin
mutlak olması. Hepsi `src/machine/SimParameters.h` içindedir.

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
| `qml/Main.qml` | Ana çerçeve: üst şerit (durum, eksenler, BAŞLAT/STOP), sol menü, sayfalar |
| `qml/ProductionPage.qml` | Üretim sayfası: açık program, üretim döngüsü, ilerleme, hidrolik, mod seçimi ve sayaçlar |
| `qml/DesignPage.qml` | Tasarım sayfası: program tablosu, boru ve kalıp, açınım boyu |
| `qml/ProgramTable.qml` | Program tablosu (TASARIM'da düzenlenir, ÜRETİM'de işlenen adımı vurgular) |
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
