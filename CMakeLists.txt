# Bu dosya CMake'e projeyi nasıl derleyeceğini anlatır ("tarif defteri").
cmake_minimum_required(VERSION 3.16)

project(BoruBukmeHmi VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Qt 6.8 veya daha yenisini bul. Bize Quick (QML) modülü yetiyor.
find_package(Qt6 6.8 REQUIRED COMPONENTS Quick)

# Qt'nin önerdiği varsayılan ayarlar (moc'un otomatik çalışması vb.).
qt_standard_project_setup(REQUIRES 6.8)

# Çıktı: appBoruHmi.exe
qt_add_executable(appBoruHmi
    src/main.cpp
)

# Theme.qml tek bir ortak nesnedir (singleton): renkler ve ölçüler orada.
set_source_files_properties(qml/Theme.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)

# QML modülü: ekran dosyaları ve QML'in tanıdığı C++ sınıfları.
qt_add_qml_module(appBoruHmi
    URI BoruHmi
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/Theme.qml
        qml/HmiButton.qml
        qml/NavButton.qml
        qml/JogButton.qml
        qml/ValueField.qml
        qml/NumericKeypad.qml
        qml/PumpControl.qml
        qml/ActuatorButton.qml
        qml/AxisDisplay.qml
        qml/ProgramTable.qml
        qml/ProductionPage.qml
        qml/DesignPage.qml
        qml/MotionPage.qml
        qml/ConfirmDialog.qml
        qml/NameDialog.qml
        qml/ProgramsDialog.qml
        qml/ProgramManager.qml
        qml/DiesPage.qml
        qml/DieDialog.qml
    SOURCES
        src/machine/Actuator.h
        src/machine/Axis.h
        src/machine/IMachine.h
        src/machine/SimParameters.h
        src/machine/SimMachine.h
        src/machine/SimMachine.cpp
        src/program/BendProgram.h
        src/program/BendProgram.cpp
        src/program/ProgramStore.h
        src/program/ProgramStore.cpp
        src/program/PartShape.h
        src/program/PartShape.cpp
        src/tooling/DieLibrary.h
        src/tooling/DieLibrary.cpp
)

# Qt'nin ürettiği kayıt kodu başlık dosyalarını yalnızca adıyla çağırır
# (#include <Axis.h>). Bu yüzden klasörleri arama yoluna ekliyoruz.
target_include_directories(appBoruHmi PRIVATE src/machine src/program src/tooling)

# Windows'ta programın arkasında siyah konsol penceresi açılmasın.
set_target_properties(appBoruHmi PROPERTIES
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appBoruHmi PRIVATE Qt6::Quick)
