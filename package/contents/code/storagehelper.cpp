#include "storagehelper.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QTextStream>

StorageHelper::StorageHelper(QObject *parent)
    : QObject(parent) {}

QString StorageHelper::readFile(const QString &path) const {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return QString();
    QTextStream in(&file);
    return in.readAll();
}

bool StorageHelper::writeFile(const QString &path, const QString &content) const {
    QFileInfo fi(path);
    QDir dir = fi.absoluteDir();
    if (!dir.exists())
        dir.mkpath(".");

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text))
        return false;
    QTextStream out(&file);
    out << content;
    return true;
}

bool StorageHelper::fileExists(const QString &path) const {
    return QFile::exists(path);
}

QString StorageHelper::storagePath() const {
    QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (base.isEmpty())
        base = QDir::homePath() + "/.local/share/akai-widget";
    QDir dir(base);
    if (!dir.exists())
        dir.mkpath(".");
    return base;
}
