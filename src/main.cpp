#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QSettings>
#include <QStandardPaths>

#include "machine/SimMachine.h"
#include "program/BendProgram.h"
#include "program/ProgramStore.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // Demo için sanal makine. Gerçek makineye geçerken değişecek satır burası
    // (ör. SiemensMachine machine;). Ekran kodu hiç değişmeyecek.
    SimMachine machine;

    // Büküm programı (reçete). Adımların alabileceği değerler makinenin eksen
    // limitlerinden gelir: program, makinenin yapamayacağı bir adım içeremez.
    BendProgram program;
    program.setStepLimits(BendProgram::Feed, 0.1,
                          machine.axisX()->maxPosition() - machine.axisX()->minPosition());
    program.setStepLimits(BendProgram::Bend, 0.1, machine.axisB()->maxPosition());
    program.setStepLimits(BendProgram::Rotate, machine.axisA()->minPosition(),
                          machine.axisA()->maxPosition());

    // Programlar Belgeler\BoruBukme\Programlar klasöründe, her biri ayrı bir dosya.
    // Gerçek makinede burası sabit bir klasör ya da fabrikanın ağ klasörü olabilir.
    const QString dataFolder = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation)
                               + QStringLiteral("/BoruBukme");
    ProgramStore store(dataFolder + QStringLiteral("/Programlar"), &program);

    // Uygulamanın ayarları (şimdilik yalnızca son açılan program) küçük bir metin dosyasında.
    QSettings settings(dataFolder + QStringLiteral("/ayarlar.ini"), QSettings::IniFormat);

    // Açılış: son kullanılan program; o açılamazsa klasördeki ilk program.
    // Klasör boşsa örnek program oraya kaydedilir (demoda liste boş görünmesin).
    const QString lastProgram = settings.value(QStringLiteral("sonProgram")).toString();
    const bool opened = (!lastProgram.isEmpty() && store.open(lastProgram)) || store.openFirst();
    if (!opened) {
        program.loadExample();
        store.saveAs(program.name());
    }

    // Açık program değiştikçe adını hatırla: bir sonraki açılışta o açılır.
    settings.setValue(QStringLiteral("sonProgram"), store.currentName());
    QObject::connect(&store, &ProgramStore::currentNameChanged, &settings, [&settings, &store] {
        settings.setValue(QStringLiteral("sonProgram"), store.currentName());
    });

    // Makinenin toplam adedi kapanınca sıfırlanmaz: gerçek makinelerde de kalıcıdır.
    machine.setTotalCount(settings.value(QStringLiteral("toplamAdet"), 0).toInt());
    QObject::connect(&machine, &IMachine::countersChanged, &settings, [&settings, &machine] {
        settings.setValue(QStringLiteral("toplamAdet"), machine.totalCount());
    });

    QQmlApplicationEngine engine;

    // Main.qml'deki "required property" alanlarını dolduruyoruz.
    // Ekran makineyi yalnızca IMachine olarak görür, arkasında ne olduğunu bilmez.
    engine.setInitialProperties({
        { QStringLiteral("machine"), QVariant::fromValue<IMachine *>(&machine) },
        { QStringLiteral("program"), QVariant::fromValue(&program) },
        { QStringLiteral("store"), QVariant::fromValue(&store) },
    });

    // QML dosyası yüklenemezse (yazım hatası vb.) programı kapat.
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, [] { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("BoruHmi", "Main");

    return app.exec();
}
