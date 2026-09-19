#include <QGuiApplication>
#include <QQmlApplicationEngine>

#include "machine/SimMachine.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // Demo için sanal makine. Gerçek makineye geçerken değişecek satır burası
    // (ör. SiemensMachine machine;). Ekran kodu hiç değişmeyecek.
    SimMachine machine;

    QQmlApplicationEngine engine;

    // Main.qml'deki "required property Machine machine" alanını dolduruyoruz.
    // Ekran nesneyi yalnızca IMachine olarak görür, arkasında ne olduğunu bilmez.
    engine.setInitialProperties({
        { QStringLiteral("machine"), QVariant::fromValue<IMachine *>(&machine) },
    });

    // QML dosyası yüklenemezse (yazım hatası vb.) programı kapat.
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, [] { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("BoruHmi", "Main");

    return app.exec();
}
