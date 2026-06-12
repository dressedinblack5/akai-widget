#ifndef STORAGEHELPER_H
#define STORAGEHELPER_H

#include <QObject>
#include <QtQml/qqmlregistration.h>

class StorageHelper : public QObject {
    Q_OBJECT
    QML_ELEMENT

public:
    explicit StorageHelper(QObject *parent = nullptr);

    Q_INVOKABLE QString readFile(const QString &path) const;
    Q_INVOKABLE bool writeFile(const QString &path, const QString &content) const;
    Q_INVOKABLE bool fileExists(const QString &path) const;
    Q_INVOKABLE QString storagePath() const;
};

#endif
