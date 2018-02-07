#include <QCoreApplication>
#include "l2tp_mac.h"
#include <QThread>


int main(int argc, char *argv[])
{
    QCoreApplication a(argc, argv);
    L2TP l2tp;
    QString ip;
    l2tp.connect("guofanghua", "123", "192.168.10.12", ip, false);
    QThread::sleep(10);
    l2tp.disconnect();
    return a.exec();
}
