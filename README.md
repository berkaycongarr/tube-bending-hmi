# Boru Bükme Makinesi – Operatör Paneli

CNC boru bükme makinesi için Windows operatör ekranı (HMI). C++ ve Qt 6 (QML) ile yazıldı.

Şu an **sanal makineyle** çalışır: gerçek makine yerine sanal bir makine (`SimMachine`) kullanılır.
Ekranın sol altındaki "SANAL MAKİNE" yazısı bunu hatırlatır.

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

## Kalıplar

Makinede kullanılabilen büküm kalıpları **KALIPLAR** sayfasında tutulur. Her kalıbın
açıklaması (ör. `25X50XR116`), kalıp yarıçapı (boru ekseninde), aldığı boru çapı ve iki
ayarı vardır: **MALAFALI BÜK** ve **BÜKÜMDE İLERLE** (müşterinin ekranındaki "AKTİF KALIP"
bilgileri). İlk açılışta müşterinin ekranındaki kalıp örnek olarak eklenir.

Kalıplar tek bir dosyada, `Belgeler\BoruBukme\kaliplar.json` içinde saklanır ve her
değişiklik hemen, güvenli biçimde (`QSaveFile`) yazılır; dosyaya yazılamazsa liste de
değişmez. Dosya bozuksa üzerine yazılmaz: `kaliplar.json.bozuk` adıyla yedeklenir ve
liste boş başlar.

**Takılı kalıp**, makinede o an duran fiziksel kalıptır. Listeden seçilip TAKILI KALIP YAP
ile (onay sorularak) işaretlenir ve `ayarlar.ini` içinde hatırlanır; kalıp listesi başka
makineye kopyalansa da "takılı" bilgisi taşınmaz. Takılı kalıp silinemez; döngü sürerken
takılı kalıp değiştirilemez.

Takılı kalıbın bilgileri makineye bildirilir (gerçek makinede PLC'ye kalıp ayarı olarak
yazılır): yay boyu kalıbın yarıçapıyla hesaplanır, malafalı kalıpta döngü malafayı ileri
çıkarır. Program kendi kalıp yarıçapını ve boru çapını saklar; takılı kalıba uymuyorsa
(ör. program R116 Ø50, kalıp R60 Ø30) BAŞLAT kilitlenir ve nedeni yazılır. Makine de
BAŞLAT'ta kendisi karşılaştırır. ÜRETİM sayfasındaki TAKILI KALIP kutusu uyumu gösterir;
dokununca KALIPLAR açılır. TASARIM'daki **TAKILI KALIBA UYDUR** programın yarıçapını ve
boru çapını takılı kalıbınkiyle değiştirir.

## Üretim döngüsü

Parçanın adımlarını **makine** yürütür; ekran yalnızca tarifi (program adımlarını) gönderir,
START/STOP der ve durumu gösterir. Gerçek makinede bu sıra PLC'nin içindedir: ekran donsa
bile makine parçayı bitirir. `SimMachine` bunu bir PLC adım zinciri gibi uygular
(`beginPhase` komutu verir, `updateCycle` her turda "bu aşama bitti mi?" diye bakar).

Bir parçanın sırası:

1. Araba boru alma konumuna (X = 500 mm), büküm kolu ve rotasyon başa (B = 0, A = 0) gider,
   malafa geri çekilir. ROTASYON değerleri mutlak olduğu için her parça A = 0'da başlar
2. Pens açıksa boru beklenir: operatör boruyu takıp pensi kapatır, START'a basar
3. Kalıp malafalıysa (MALAFALI BÜK) malafa ileri çıkar
4. Program adımları sırayla işlenir:
   - **İLERLE** (göreli): araba boruyu bu kadar mm ilerletir
   - **BÜK** (mutlak açı): mengene kapanır → (bekleme) → kol açıya döner → (bekleme) →
     mengene açılır → kol başa döner. Bekleme süreleri ZAMANLAR sayfasındadır.
     Pens boruyu tuttuğu için büküm sırasında araba yayı takip eder (yay boyu = kalıp
     yarıçapı × açı), böylece arabanın gittiği toplam yol programın açınım boyuna eşit olur.
     BÜKÜMDE İLERLE açıksa araba motorla itilir (destek), kapalıysa boru onu sürükler;
     iki durumda da araba aynı yere varır
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

Döngü şu durumlarda başlamaz: makine referanssız, pompa durmuş, takılı kalıp yok ya da
program ona uymuyor, mengene kapalı ya da boru beklenirken pens açık.

Döngü sırasında elle kumanda (jog, konuma git, silindirler, referans arama) kilitlidir ve
butonlar nedenini yazar. Eksenler, döngü operatörü beklerken de kilitli kalır: araba
oynatılırsa döngü kaldığı yerden yanlış devam eder. Silindirler ise beklerken serbesttir,
çünkü boruyu takmak için pens gerekir. STOP döngüyü keser.

Basınç kesilirse ya da bir aşama beklenen sürede bitmezse döngü arızayla durur; silindirler
olduğu gibi kalır — yarıda kalan bir parçada mengenenin kendiliğinden açılması tehlikelidir,
kararı operatör verir.

Varsayımlar (demoda müşteriye sorulacak): boru alma konumu (`src/machine/SimParameters.h`),
ZAMANLAR'daki sürelerin kendileri ve varsayılan değerleri, BÜK ile ROTASYON değerlerinin
mutlak olması, BÜKÜMDE İLERLE'nin "araba motorla itilir" anlamına gelmesi.

## Zamanlar ve ayarcı şifresi

**ZAMANLAR** sayfası makinenin sürelerini gösterir ve değiştirir:

| Süre | Varsayılan | Aralık | Ne zaman |
|---|---|---|---|
| Mengene kapanınca bekleme | 0.20 s | 0 – 5 s | Mengene kapandıktan sonra, büküme başlamadan önce |
| Bükümde bekleme | 0.30 s | 0 – 5 s | Kol açıya varınca, mengene açılmadan önce (geri esneme azalır) |
| Adım arası bekleme | 0.30 s | 0 – 5 s | Otomatik çalışmada iki adım arasında |
| Eksen zaman aşımı | 45 s | 5 – 300 s | Bir eksen hareketi bu sürede bitmezse döngü arızayla durur |
| Silindir zaman aşımı | 8 s | 1 – 60 s | Mengene, malafa ya da pens bu sürede yerine gitmezse arıza |

Süreler makinenin belleğinde durur: gerçek makinede PLC'nin kalıcı belleğinde, sanal
makinede `Belgeler\BoruBukme\makine.ini` dosyasında. Değişen süre hemen geçerli olur;
döngü sürerken değiştirilirse sıradaki aşamada kullanılır. Varsayılandan farklı olan
sürenin "Varsayılan" yazısı turuncudur; ↺ varsayılana döndürür. Dosyada sayı olmayan ya
da aralık dışında bir değer varsa yok sayılır, varsayılan kullanılır.

Değerleri herkes görür; değiştirmek için **ayarcı şifresi** gerekir (sanayi ekranlarındaki
yetki seviyesi: operatör üretir, ayarcı makineyi ayarlar). **Varsayılan şifre: `1234`.**
Kilit açılınca 10 dakika açık kalır, her değişiklikte süre baştan başlar; süre dolunca
kendiliğinden kilitlenir. Kilit açıkken ekranın altında "AYAR AÇIK" yazar; ona ya da
KİLİTLE'ye dokununca hemen kilitlenir. Uygulama her açılışta kilitli başlar. Şifrenin
kendisi hiçbir yerde saklanmaz; değiştirilirse yalnızca özeti (SHA-256) `ayarlar.ini`
içinde durur. (Şifreyi değiştirme AYARLAR sayfasıyla gelecek.)

## Parçanın şekli ve SİMÜLASYON

`PartShape`, programdan parçanın şeklini hesaplar: borunun eksen çizgisini (merkez hattını)
üç boyutta çıkarır. Şekli SİMÜLASYON sekmesi çizer; hesap çizimden ayrıdır ve ekransız
test edilir. Program her değiştiğinde (adım, açı, kalıp yarıçapı) şekil yeniden hesaplanır.

Hesap, borunun ekseni boyunca yönünü bilen bir okla yürür: İLERLE oku düz ilerletir, BÜK oku
kalıp yarıçapında bir yay üzerinde döndürür, ROTASYON ise sonraki dirseklerin düzlemini
değiştirir. Parça (0, 0, 0)'dan +X yönünde başlar, ilk dirsek +Y'ye döner; rotasyonsuz parça
tek düzlemde kalır. Eksen çizgisinin boyu programın açınım boyuna eşittir.

Varsayımlar: açılar programdaki gibi alınır (boru esnemesi hesaba katılmaz); ROTASYON'un
dönüş yönü müşteriye sorulacak. Yön ters çıkarsa parça ayna görüntüsü gibi çizilir;
düzeltmek için `PartShape.cpp`'de tek bir işaret değişir.

**SİMÜLASYON**, müşterinin ekranındaki gibi tablonun üstündeki iki sekmeden ikincisidir
(**LİSTE | SİMÜLASYON**); hem ÜRETİM'de hem TASARIM'da vardır. Parça, borunun gerçek
çapıyla ve adım numaralarıyla çizilir:

- **ÜST**, **YAN** ve **3B** hazır bakış açılarıdır; parmakla sürükleyerek de döndürülür.
  Görünüm parçaya her an sığdırılır.
- ÜRETİM'de döngü sürerken bitmiş adımlar koyu, işlenen adım turuncu, sıradakiler açık
  renkte görünür.
- TASARIM'da LİSTE'de seçilen adım mavi görünür. SİMÜLASYON açıkken de adım eklenebilir:
  parça çizimde hemen değişir.

Çizim ek bir Qt modülü gerektirmez (QML Canvas): parça "ressam algoritmasıyla" uzaktan
yakına boyanır, uzaktaki yerler biraz soluk görünür. Ayrıntılar `qml/PartView.qml` içinde.

## Klasör yapısı

| Dosya | Görevi |
|---|---|
| `src/main.cpp` | Giriş noktası: makineyi ve programı oluşturur, ekranı yükler |
| `src/machine/Axis.h` | Eksen: konum, hareket, referans, limit ve kilit durumu |
| `src/machine/Actuator.h` | Hidrolik silindir: komut, sensör durumu ve kilit |
| `src/machine/IMachine.h` | Makine sözleşmesi: ekranın tanıdığı tek sınıf |
| `src/machine/SimMachine.*` | Sanal makine (demo) |
| `src/machine/SimParameters.h` | Sanal makinenin ayarları: limitler, hızlar, sürelerin varsayılanları |
| `src/program/BendProgram.*` | Büküm programı (reçete): komut listesi, açınım boyu, doğrulama, JSON biçimi |
| `src/program/ProgramStore.*` | Program deposu: klasördeki dosyalar, aç / kaydet / sil |
| `src/program/PartShape.*` | Parçanın şekli: programdan borunun eksen çizgisini (3B) hesaplar |
| `src/tooling/DieLibrary.*` | Kalıp kütüphanesi: kalıplar, takılı kalıp, `kaliplar.json` biçimi |
| `src/machine/ParameterList.*` | Makinenin ayarlanabilir değerleri (süreler): başlık, birim, varsayılan, aralık |
| `src/access/AccessControl.*` | Ayarcı şifresi: kilidi açma, kendiliğinden kilitlenme, şifre özeti |
| `qml/Main.qml` | Ana çerçeve: üst şerit (durum, eksenler, BAŞLAT/STOP), sol menü, sayfalar |
| `qml/ProductionPage.qml` | Üretim sayfası: açık program, LİSTE / SİMÜLASYON, takılı kalıp, üretim döngüsü, ilerleme, hidrolik, mod seçimi ve sayaçlar |
| `qml/DesignPage.qml` | Tasarım sayfası: LİSTE (program tablosu) / SİMÜLASYON, boru ve kalıp, takılı kalıba uyum, açınım boyu |
| `qml/ProgramTable.qml` | Program tablosu (TASARIM'da düzenlenir, ÜRETİM'de işlenen adımı vurgular) |
| `qml/PartView.qml` | SİMÜLASYON: parçanın üç boyutlu çizimi, bakış açıları, üretimde adım renkleri |
| `qml/ViewTabs.qml` | LİSTE / SİMÜLASYON sekmeleri |
| `qml/DiesPage.qml` | Kalıplar sayfası: kalıp listesi, takılı kalıp, YENİ / DÜZENLE / SİL / TAKILI KALIP YAP |
| `qml/DieDialog.qml` | Kalıp ekleme ve düzenleme penceresi |
| `qml/ProgramManager.qml` | Program dosya işlemlerinin akışı ve soruları |
| `qml/ProgramsDialog.qml` | Programlar penceresi: liste, AÇ / YENİ / FARKLI KAYDET / SİL |
| `qml/NameDialog.qml` | Program adı girme penceresi |
| `qml/ConfirmDialog.qml` | Onay ve bilgi penceresi |
| `qml/MotionPage.qml` | Hareket sayfası: jog, hedef konuma gitme ve hidrolik |
| `qml/TimersPage.qml` | Zamanlar sayfası: makinenin süreleri, varsayılana dönme |
| `qml/LockBar.qml` | Ayar kilidi şeridi ve şifre sorma (ayar sayfaları için) |
| `qml/Theme.qml` | Renkler ve ölçüler |
| `qml/HmiButton.qml` | Dokunmatik buton |
| `qml/JogButton.qml` | Push buton mantığıyla jog butonu |
| `qml/NavButton.qml` | Sol menü butonu |
| `qml/ValueField.qml` | Dokununca tuş takımı açan değer alanı |
| `qml/NumericKeypad.qml` | Dokunmatik sayı tuş takımı (aralık denetimli; şifre için gizli yazım) |
| `qml/PumpControl.qml` | Hidrolik pompa: START/STOP, durum ve basınç |
| `qml/ActuatorButton.qml` | Kalıcı buton mantığıyla silindir kumandası |
| `qml/AxisDisplay.qml` | Eksen konum göstergesi |
