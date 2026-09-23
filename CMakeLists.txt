# Bu dosya CMake'e projeyi nasıl derleyeceğini anlatır ("tarif defteri").
cmake_minimum_required(VERSION 3.16)

project(BoruBukmeHmi VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Demo paketi düz bir klasör olsun: exe, Qt'nin DLL'leri ve veri klasörü yan yana dursun.
# Qt bu değeri find_package sırasında okuyup dağıtım aracına (windeployqt) verdiği için
# find_package'dan ÖNCE ayarlanmalıdır. Varsayılanı "bin" olurdu: o zaman exe kökte,
# DLL'ler bin\ altında kalır ve program Qt kurulu olmayan bilgisayarda açılmaz.
set(CMAKE_INSTALL_BINDIR ".")

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
        qml/ViewTabs.qml
        qml/PartView.qml
        qml/LockBar.qml
        qml/TimersPage.qml
        qml/SettingsPage.qml
        qml/IoTestPage.qml
        qml/AlarmsDialog.qml
        qml/SimulatorDialog.qml
    SOURCES
        src/machine/Actuator.h
        src/machine/Axis.h
        src/machine/IMachine.h
        src/machine/ParameterList.h
        src/machine/ParameterList.cpp
        src/machine/IoList.h
        src/machine/IoList.cpp
        src/machine/AlarmList.h
        src/machine/AlarmList.cpp
        src/machine/SimParameters.h
        src/machine/SimMachine.h
        src/machine/SimMachine.cpp
        src/machine/SimControls.h
        src/machine/SimControls.cpp
        src/program/BendProgram.h
        src/program/BendProgram.cpp
        src/program/ProgramStore.h
        src/program/ProgramStore.cpp
        src/program/PartShape.h
        src/program/PartShape.cpp
        src/tooling/DieLibrary.h
        src/tooling/DieLibrary.cpp
        src/access/AccessControl.h
        src/access/AccessControl.cpp
)

# Qt'nin ürettiği kayıt kodu başlık dosyalarını yalnızca adıyla çağırır
# (#include <Axis.h>). Bu yüzden klasörleri arama yoluna ekliyoruz.
# resources da burada: Windows kaynak derleyicisi (windres) app.ico'yu bu yolda arar.
target_include_directories(appBoruHmi PRIVATE
    src/machine src/program src/tooling src/access resources
)

# Windows'ta programın arkasında siyah konsol penceresi açılmasın.
set_target_properties(appBoruHmi PROPERTIES
    WIN32_EXECUTABLE TRUE
)

# Programın ikonu ve "Özellikler" penceresinde görünen bilgiler exe'nin içine gömülür.
if(WIN32)
    target_sources(appBoruHmi PRIVATE resources/app.rc)
endif()

target_link_libraries(appBoruHmi PRIVATE Qt6::Quick)

# --- Demo paketi ------------------------------------------------------------------
# Amaç: Qt kurulu olmayan bir bilgisayarda da çalışan tek klasör. Kurulum şunu yapar:
#   1) exe'yi klasöre kopyalar,
#   2) Qt'nin gerektirdiği DLL'leri ve QML modüllerini yanına koyar (windeployqt),
#   3) MinGW'nin çalışma zamanı kitaplıklarını ekler.
# Kullanımı README'deki "Demo paketi" bölümünde.
install(TARGETS appBoruHmi
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# Paketin kendi veri klasörü: kurulan sürüm programları, kalıpları ve ayarları kendi
# yanında tutar; klasörü USB'ye kopyalayınca hepsi beraber gider ve çalıştığı
# bilgisayarda iz bırakmaz. Qt Creator'dan çalıştırılan sürümün yanında böyle bir klasör
# olmadığı için orada veriler Belgeler\BoruBukme altına yazılmaya devam eder.
install(DIRECTORY DESTINATION veri)

# NO_TRANSLATIONS: Qt'nin kendi hazır çevirileri (32 dil, ~7 MB) bu programda
# kullanılmıyor — ekrandaki bütün yazılar zaten Türkçe yazılmış durumda.
qt_generate_deploy_qml_app_script(
    TARGET appBoruHmi
    OUTPUT_SCRIPT deploy_script
    MACOS_BUNDLE_POST_BUILD
    NO_UNSUPPORTED_PLATFORM_ERROR
    NO_TRANSLATIONS
)
install(SCRIPT ${deploy_script})

# MinGW ile derlenen program bu üç kitaplığa muhtaçtır; bazı Qt sürümlerinde yukarıdaki
# adım bunları kopyalamıyor ve program başka bilgisayarda "DLL bulunamadı" diye açılmıyor.
# Derleyicinin yanındaki dosyaları buluyorsak paketin içine biz koyuyoruz.
if(WIN32 AND CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    get_filename_component(mingw_bin "${CMAKE_CXX_COMPILER}" DIRECTORY)
    foreach(runtime_dll libgcc_s_seh-1 libstdc++-6 libwinpthread-1)
        if(EXISTS "${mingw_bin}/${runtime_dll}.dll")
            install(FILES "${mingw_bin}/${runtime_dll}.dll" DESTINATION .)
        endif()
    endforeach()
endif()
