#ifndef L2TP_H
#define L2TP_H

#include <QString>
#include <string>
using namespace std;


class L2TP
{
public:
    L2TP();
    ~L2TP();

    int connect(const QString &userName, const QString &password, const QString &server, QString &userIp, bool dialByPhoneBook);
    int disconnect();
    int isConnected();

private:

    int modifyVPNService(int opType);
    int createVPNService();
    int deleteVPNService();
    int existVPNService();

private:
    string m_userName;
    string m_password;
    string m_server;
    string m_userIp;
    bool m_dialByPhoneBook;
};

#endif // HELLO_H
