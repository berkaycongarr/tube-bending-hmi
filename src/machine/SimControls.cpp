#include "SimControls.h"

#include "SimMachine.h"

SimControls::SimControls(SimMachine *machine, QObject *parent)
    : QObject(parent)
    , m_machine(machine)
{
    // Acil stop makinenin durumudur: başka bir yerden değişirse panel de yenilensin.
    if (m_machine)
        connect(m_machine, &IMachine::emergencyStopChanged, this, &SimControls::changed);
}

bool SimControls::isEmergencyStop() const
{
    return m_machine && m_machine->isEmergencyStop();
}

bool SimControls::isPressureLoss() const
{
    return m_machine && m_machine->isPressureLoss();
}

bool SimControls::hasSensorFault() const
{
    return m_machine && m_machine->hasSensorFault();
}

QString SimControls::sensorLabel() const
{
    return SimMachine::faultSensorLabel();
}

void SimControls::pressEmergencyStop(bool pressed)
{
    if (!m_machine)
        return;
    m_machine->pressEmergencyStop(pressed);
    emit changed();
}

void SimControls::setPressureLoss(bool active)
{
    if (!m_machine)
        return;
    m_machine->setPressureLoss(active);
    emit changed();
}

void SimControls::setSensorFault(bool faulty)
{
    if (!m_machine)
        return;
    m_machine->setSensorFault(faulty);
    emit changed();
}
