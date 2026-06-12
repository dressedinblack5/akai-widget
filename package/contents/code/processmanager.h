#ifndef PROCESSMANAGER_H
#define PROCESSMANAGER_H

#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

class ProcessManager : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool serverRunning READ serverRunning NOTIFY serverRunningChanged)

public:
    explicit ProcessManager(QObject *parent = nullptr);
    ~ProcessManager();

    bool serverRunning() const;

    Q_INVOKABLE void startServer();
    Q_INVOKABLE void stopServer();
    Q_INVOKABLE void restartServer();

signals:
    void serverRunningChanged();
    void serverStarted();
    void serverStopped();
    void serverError(const QString &error);

private slots:
    void onProcessStarted();
    void onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void onProcessError(QProcess::ProcessError error);
    void onStartTimeout();
    void onKillTimeout();

private:
    QProcess *m_process = nullptr;
    QTimer *m_startTimer = nullptr;
    QTimer *m_killTimer = nullptr;
    bool m_serverRunning = false;
    bool m_starting = false;
};

#endif
