#include "PartShape.h"

#include <QQuaternion>
#include <QtMath>

#include <algorithm>
#include <cmath>

PartShape::PartShape(QObject *parent)
    : QObject(parent)
{
}

void PartShape::setProgram(BendProgram *program)
{
    if (m_program == program)
        return;

    disconnect(m_connection);
    m_program = program;

    // Program her değiştiğinde (adım, değer, kalıp yarıçapı, başka program) şekil
    // yeniden hesaplanır. Birkaç adımlık bir programda bu, milisaniyenin altındadır.
    if (m_program)
        m_connection = connect(m_program, &BendProgram::summaryChanged, this, &PartShape::rebuild);

    emit programChanged();
    rebuild();
}

QVariantList PartShape::pieces() const
{
    QVariantList list;
    list.reserve(m_pieces.size());
    for (const Piece &piece : m_pieces) {
        list.append(QVariantMap {
            { QStringLiteral("x1"), piece.a.x() },
            { QStringLiteral("y1"), piece.a.y() },
            { QStringLiteral("z1"), piece.a.z() },
            { QStringLiteral("x2"), piece.b.x() },
            { QStringLiteral("y2"), piece.b.y() },
            { QStringLiteral("z2"), piece.b.z() },
            { QStringLiteral("step"), piece.step },
            { QStringLiteral("arc"), piece.arc },
        });
    }
    return list;
}

QVariantList PartShape::labels() const
{
    QVariantList list;
    list.reserve(m_labels.size());
    for (const Label &label : m_labels) {
        list.append(QVariantMap {
            { QStringLiteral("x"), label.position.x() },
            { QStringLiteral("y"), label.position.y() },
            { QStringLiteral("z"), label.position.z() },
            { QStringLiteral("step"), label.step },
            { QStringLiteral("command"), label.command },
        });
    }
    return list;
}

void PartShape::rebuild()
{
    m_pieces.clear();
    m_labels.clear();
    m_length = 0.0;
    m_planar = true;
    m_planeNormal = QVector3D(0.0f, 0.0f, 1.0f);

    // Yürüyüşün başı: konum p, borunun yönü t, dirseğin döneceği yön n.
    QVector3D p(0.0f, 0.0f, 0.0f);
    QVector3D t(1.0f, 0.0f, 0.0f);
    QVector3D n(0.0f, 1.0f, 0.0f);
    double rotation = 0.0; // borunun şu anki rotasyonu (derece): parça başında 0
    bool firstBend = true;

    const int count = m_program ? m_program->count() : 0;
    const double dieRadius = m_program ? m_program->dieRadius() : 0.0;

    for (int i = 0; i < count; ++i) {
        const BendProgram::Step step = m_program->step(i);

        switch (step.command) {
        case BendProgram::Feed: {
            // İLERLE: düz parça. Önde/arkada sıralaması doğru olsun diye bölünür.
            const double length = std::max(0.0, step.value);
            const int parts = std::clamp(int(std::ceil(length / FeedStepMm)), 1, 40);
            const QVector3D start = p;
            for (int k = 0; k < parts; ++k) {
                const QVector3D a = start + t * float(length * k / parts);
                const QVector3D b = start + t * float(length * (k + 1) / parts);
                m_pieces.append({ a, b, i, false });
            }
            p = start + t * float(length);
            m_labels.append({ start + t * float(length / 2.0), i, BendProgram::Feed });
            m_length += length;
            break;
        }

        case BendProgram::Bend: {
            // BÜK: dirseğin merkezi, borunun R kadar n yönündedir. Nokta ve yönler,
            // dirseğin ekseni b = t × n etrafında θ kadar döner.
            const double angle = std::max(0.0, step.value);
            const QVector3D axis = QVector3D::crossProduct(t, n).normalized();
            const QVector3D center = p + n * float(dieRadius);
            const QVector3D fromCenter = p - center;
            const int parts = std::clamp(int(std::ceil(angle / ArcStepDegrees)), 2, 48);

            QVector3D previous = p;
            for (int k = 1; k <= parts; ++k) {
                const QQuaternion turn = QQuaternion::fromAxisAndAngle(axis, float(angle * k / parts));
                const QVector3D point = center + turn.rotatedVector(fromCenter);
                m_pieces.append({ previous, point, i, true });
                previous = point;
            }

            const QQuaternion half = QQuaternion::fromAxisAndAngle(axis, float(angle / 2.0));
            m_labels.append({ center + half.rotatedVector(fromCenter), i, BendProgram::Bend });

            const QQuaternion turn = QQuaternion::fromAxisAndAngle(axis, float(angle));
            p = previous;
            t = turn.rotatedVector(t);
            n = turn.rotatedVector(n);
            m_length += dieRadius * qDegreesToRadians(angle);

            // Bütün dirsekler aynı eksen etrafında dönüyorsa parça tek bir düzlemdedir.
            if (firstBend) {
                m_planeNormal = axis;
                firstBend = false;
            } else if (QVector3D::crossProduct(axis, m_planeNormal).length() > 1e-4f) {
                m_planar = false;
            }
            break;
        }

        case BendProgram::Rotate: {
            // ROTASYON mutlak bir açıdır: boru bir önceki konumundan farkı kadar döner
            // ve sonraki dirseklerin yönü (n) borunun ekseni (t) etrafında o kadar döner.
            // Dönüş yönü bir varsayım: yanlışsa parça ayna görüntüsü gibi çizilir.
            const double delta = step.value - rotation;
            rotation = step.value;
            n = QQuaternion::fromAxisAndAngle(t, float(delta)).rotatedVector(n);
            m_labels.append({ p, i, BendProgram::Rotate });
            break;
        }
        }

        // Kayan noktalı hesabın küçük sapmaları birikmesin: yönleri birim ve dik tut.
        t.normalize();
        n = (n - t * QVector3D::dotProduct(n, t)).normalized();
    }

    m_end = p;
    m_endDirection = t;

    // Parçayı içine alan kutu, ondan da küre: görünümü ekrana sığdırmak için.
    if (m_pieces.isEmpty()) {
        m_center = QVector3D();
        m_radius = 0.0;
    } else {
        QVector3D low = m_pieces.first().a;
        QVector3D high = low;
        for (const Piece &piece : std::as_const(m_pieces)) {
            for (const QVector3D &point : { piece.a, piece.b }) {
                low = QVector3D(std::min(low.x(), point.x()), std::min(low.y(), point.y()),
                                std::min(low.z(), point.z()));
                high = QVector3D(std::max(high.x(), point.x()), std::max(high.y(), point.y()),
                                 std::max(high.z(), point.z()));
            }
        }
        m_center = (low + high) / 2.0f;
        m_radius = std::max(1.0, double((high - low).length() / 2.0f));
    }

    emit shapeChanged();
}
