#include "processmanager.h"

ProcessManager::ProcessManager(QObject *parent)
    : QObject(parent) {
    m_startTimer = new QTimer(this);
    m_startTimer->setSingleShot(true);
    m_startTimer->setInterval(5000);
    connect(m_startTimer, &QTimer::timeout, this, &ProcessManager::onStartTimeout);

    m_killTimer = new QTimer(this);
    m_killTimer->setSingleShot(true);
    m_killTimer->setInterval(3000);
    connect(m_killTimer, &QTimer::timeout, this, &ProcessManager::onKillTimeout);
}

ProcessManager::~ProcessManager() {
    m_startTimer->stop();
    m_killTimer->stop();

    if (m_process) {
        m_process->disconnect(this);
        m_process->terminate();
        if (!m_process->waitForFinished(3000)) {
            m_process->kill();
            m_process->waitForFinished(1000);
        }
    }
}

bool ProcessManager::serverRunning() const {
    return m_serverRunning;
}

void ProcessManager::startServer() {
    if (m_serverRunning || m_starting)
        return;

    if (m_process) {
        m_process->deleteLater();
        m_process = nullptr;
    }

    m_process = new QProcess(this);
    connect(m_process, &QProcess::started, this, &ProcessManager::onProcessStarted);
    connect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &ProcessManager::onProcessFinished);
    connect(m_process, &QProcess::errorOccurred, this, &ProcessManager::onProcessError);

    m_starting = true;
    m_startTimer->start();
    m_process->start("opencode", QStringList() << "serve" << "--pure" << "--log-level" << "ERROR");
}

void ProcessManager::stopServer() {
    m_startTimer->stop();
    m_killTimer->stop();
    m_starting = false;

    if (!m_process || !m_serverRunning)
        return;

    m_process->terminate();
    m_killTimer->start();
}

void ProcessManager::restartServer() {
    if (m_process) {
        m_process->disconnect(this);
        connect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this](int, QProcess::ExitStatus) {
            if (m_process) {
                m_process->deleteLater();
                m_process = nullptr;
            }
            startServer();
        });
        m_process->kill();
    } else {
        m_serverRunning = false;
        emit serverRunningChanged();
        startServer();
    }
}

void ProcessManager::onProcessStarted() {
    m_startTimer->stop();
    m_starting = false;
    m_serverRunning = true;
    emit serverRunningChanged();
    emit serverStarted();
}

void ProcessManager::onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus) {
    Q_UNUSED(exitCode)
    Q_UNUSED(exitStatus)
    m_startTimer->stop();
    m_killTimer->stop();
    m_starting = false;
    m_serverRunning = false;
    emit serverRunningChanged();
    emit serverStopped();
}

void ProcessManager::onProcessError(QProcess::ProcessError error) {
    m_startTimer->stop();
    m_starting = false;

    QString errorMsg;
    switch (error) {
    case QProcess::FailedToStart:
        errorMsg = "Failed to start opencode. Is it installed and in PATH?";
        break;
    case QProcess::Crashed:
        errorMsg = "opencode server crashed";
        break;
    case QProcess::Timedout:
        errorMsg = "opencode server timed out";
        break;
    case QProcess::WriteError:
        errorMsg = "Write error communicating with opencode";
        break;
    case QProcess::ReadError:
        errorMsg = "Read error communicating with opencode";
        break;
    default:
        errorMsg = "Unknown error with opencode server";
        break;
    }
    emit serverError(errorMsg);
}

void ProcessManager::onStartTimeout() {
    if (!m_starting)
        return;
    m_starting = false;
    if (m_process) {
        m_process->kill();
        m_process->deleteLater();
        m_process = nullptr;
    }
    emit serverError("Server failed to start within 5 seconds");
}

void ProcessManager::onKillTimeout() {
    if (m_process && m_serverRunning) {
        m_process->kill();
    }
}
