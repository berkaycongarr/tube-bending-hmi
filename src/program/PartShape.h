#pragma once

#include <QList>
#include <QObject>
#include <QPointer>
#include <QVariantList>
#include <QVector3D>
#include <QtQml/qqmlregistration.h>

#include "BendProgram.h"

// Parçanın şekli: büküm programından borunun eksen çizgisini (merkez hattını) hesaplar.
//
// Borunun ekseni boyunca, yönünü bilen bir okla yürünür:
//   İLERLE L    ok gösterdiği yöne L kadar ilerler: düz parça
//   BÜK θ       ok, R yarıçaplı bir yay üzerinde θ kadar döner: dirsek
//   ROTASYON φ  boru kendi ekseninde döner: sonraki dirseklerin düzlemi değişir
// Okun bıraktığı iz parçanın kendisidir.
//
// Oku üç yönle tarif ediyoruz: t (teğet: borunun gittiği yön), n (dirseğin döneceği
// yön: kalıbın merkezine doğru) ve ikisine dik b = t × n (dirseğin dönme ekseni).
// Dirsek, noktayı ve yönleri b ekseni etrafında θ kadar döndürür; rotasyon ise n'yi
// t ekseni etrafında döndürür.
//
// Koordinatlar parçanın kendi çerçevesindedir: başlangıç (0,0,0), boru +X yönünde
// ilerler, ilk dirsek +Y yönüne döner. Rotasyonsuz bir parça XY düzleminde kalır.
// Açılar programdaki gibidir: boru esnemesi (geri yaylanma) hesaba katılmaz.
//
// Hesap çizimden ayrıdır: SİMÜLASYON bu sınıfın sonucunu çizer. İleride gerçek 3B
// çizime geçilse de bu sınıf aynı kalır.
class PartShape : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(BendProgram *program READ program WRITE setProgram NOTIFY programChanged)
    Q_PROPERTY(QVariantList pieces READ pieces NOTIFY shapeChanged)
    Q_PROPERTY(QVariantList labels READ labels NOTIFY shapeChanged)
    Q_PROPERTY(QVector3D center READ center NOTIFY shapeChanged)
    Q_PROPERTY(double radius READ radius NOTIFY shapeChanged)
    Q_PROPERTY(double length READ length NOTIFY shapeChanged)
    Q_PROPERTY(bool planar READ isPlanar NOTIFY shapeChanged)
    Q_PROPERTY(QVector3D planeNormal READ planeNormal NOTIFY shapeChanged)
    Q_PROPERTY(bool empty READ isEmpty NOTIFY shapeChanged)

public:
    // Çizimin bir parçası: kısa bir düz çizgi. Yaylar böyle küçük parçalara bölünür;
    // uzun düz parçalar da bölünür ki çizimde önde/arkada sıralaması doğru olsun.
    struct Piece
    {
        QVector3D a;
        QVector3D b;
        int step = -1;   // hangi program adımına ait
        bool arc = false; // dirseğin parçası mı?
    };

    // Bir adımın etiketi: adım numarasının yazılacağı yer.
    struct Label
    {
        QVector3D position;
        int step = -1;
        int command = BendProgram::Feed;
    };

    // Bir yayın kaç parçaya bölüneceği: her parça en çok bu kadar derece.
    static constexpr double ArcStepDegrees = 7.5;
    // Düz parçalar en çok bu kadar mm'lik parçalara bölünür.
    static constexpr double FeedStepMm = 25.0;

    explicit PartShape(QObject *parent = nullptr);

    BendProgram *program() const { return m_program; }
    void setProgram(BendProgram *program);

    QVariantList pieces() const; // QML için: { x1, y1, z1, x2, y2, z2, step, arc }
    QVariantList labels() const; // QML için: { x, y, z, step, command }

    QVector3D center() const { return m_center; } // parçayı içine alan kürenin merkezi
    double radius() const { return m_radius; }    // ve yarıçapı (görünümü sığdırmak için)
    double length() const { return m_length; }    // eksen çizgisinin boyu: açınım boyu
    bool isPlanar() const { return m_planar; }    // parça tek bir düzlemde mi?
    QVector3D planeNormal() const { return m_planeNormal; } // o düzlemin dik yönü (ilk dirsekten)
    bool isEmpty() const { return m_pieces.isEmpty(); }

    // C++ tarafı ve testler için
    const QList<Piece> &pieceList() const { return m_pieces; }
    const QList<Label> &labelList() const { return m_labels; }
    QVector3D endPoint() const { return m_end; }            // borunun ucu
    QVector3D endDirection() const { return m_endDirection; } // uçtaki yön

signals:
    void programChanged();
    void shapeChanged();

private:
    void rebuild();

    QPointer<BendProgram> m_program;
    QMetaObject::Connection m_connection;
    QList<Piece> m_pieces;
    QList<Label> m_labels;
    QVector3D m_center;
    double m_radius = 0.0;
    double m_length = 0.0;
    bool m_planar = true;
    QVector3D m_planeNormal { 0.0f, 0.0f, 1.0f };
    QVector3D m_end;
    QVector3D m_endDirection { 1.0f, 0.0f, 0.0f };
};
