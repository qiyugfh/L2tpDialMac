#include "l2tp_mac.h"
#import <SystemConfiguration/SCNetworkConfiguration.h>
#import <Foundation/Foundation.h>
#import <Foundation/NSArray.h>
#import <CoreFoundation/CFDictionary.h>
#import <security/SecKeychain.h>
#include <security/SecBase.h>
#include <QDebug>


#define VPN_NAME "My VPN Test"

CFStringRef g_serviceID;
SCPreferencesRef g_prefs = nil;

CFDictionaryRef l2tpPPPConfig(const NSString *serviceID, const NSString *serverAddress, const NSString *username);
CFDictionaryRef l2tpIPSecConfig(const NSString *serviceID);
CFDictionaryRef l2tpIPv4Config();
int getAuthorization();
int getRootAuthorization();



L2TP::L2TP()
{

}

L2TP::~L2TP()
{

}

int L2TP::connect(const QString &userName, const QString &password, const QString &server, QString &userIp, bool dialByPhoneBook)
{
    m_userName = userName.toStdString();
    m_password = password.toStdString();
    m_server = server.toStdString();
    m_dialByPhoneBook = dialByPhoneBook;

    if(existVPNService() < 0)
    {
        if(modifyVPNService(0) < 0)
        {
            qWarning("Failed to create VPN service.");
            return -1;
        }
    }

    NSString *serviceID = (NSString *)g_serviceID;
    if(serviceID == nil || [serviceID length] == 0)
    {
        qWarning("No valid service to connect.");
        return -1;
    }

    SCNetworkConnectionRef connectionRef = SCNetworkConnectionCreateWithServiceID(kCFAllocatorDefault, g_serviceID, NULL, NULL);

    NSString *server_Address = [NSString stringWithUTF8String:m_server.c_str()];
    NSString *user_Name = [NSString stringWithUTF8String:m_userName.c_str()];

    Boolean flag  = SCNetworkConnectionStart(connectionRef, l2tpPPPConfig(serviceID, server_Address, user_Name), TRUE);
    if(flag == FALSE)
    {
        qWarning("Failed to start the connection %s. %s", [serviceID UTF8String], SCErrorString(SCError()));
    }
    else
    {
        qDebug("Successfully to start the connection %s.", [serviceID UTF8String]);
    }

    userIp = QString::fromStdString(m_userIp);
    return flag;
}

int L2TP::disconnect()
{
    if(existVPNService() < 0)
    {
        return 0;
    }

    NSString *serviceID = (NSString *)g_serviceID;
    if(serviceID == nil || [serviceID length] == 0)
    {
        qWarning("exist the service, but is invalid.");
        return -1;
    }

    SCNetworkConnectionRef connectionRef = SCNetworkConnectionCreateWithServiceID(kCFAllocatorDefault, g_serviceID, NULL, NULL);
    Boolean flag = SCNetworkConnectionStop(connectionRef, TRUE);
    if(flag == FALSE)
    {
        qWarning("Cann't force disconnect the connection %s. %s",  [serviceID UTF8String], SCErrorString(SCError()));
        return -1;
    }
    else
    {
        qDebug("Successfully to disconnect the connection %s.",  [serviceID UTF8String]);
    }

    return modifyVPNService(1);
}

int L2TP::isConnected()
{
    SCNetworkConnectionRef connectionRef = SCNetworkConnectionCreateWithServiceID(kCFAllocatorDefault, g_serviceID, NULL, NULL);
    SCNetworkConnectionStatus connectStatus = SCNetworkConnectionGetStatus(connectionRef);
    switch(connectStatus)
    {
    case kSCNetworkConnectionDisconnected:
        qDebug("Service is disconnected.");
        break;
    case kSCNetworkConnectionDisconnecting:
        qDebug("Service is disconnecting.");
        break;
    case kSCNetworkConnectionConnected:
        qDebug("Service is connected.");
        break;
    case kSCNetworkConnectionConnecting:
        qDebug("Service is connecting.");
        break;
    case kSCNetworkConnectionInvalid:
        qDebug("Service is vinalid.");
    default:
        qDebug("Unexpected status.");
        break;
    }
    return connectStatus;
}

int L2TP::modifyVPNService(int opType)
{
    Boolean flag = FALSE;
    int ret = 0;

    if(getAuthorization() != 0)
    {
        return -1;
    }

    if(SCPreferencesLock(g_prefs, FALSE)){
        qDebug("Gained superhuman rights.");
    }
    else
    {
        qWarning("Sorry, without superuser privileges, I won't be able to modify any VPN interfaces.");
        return -1;
    }

    switch(opType)
    {
    case 0:
        ret = createVPNService();
        break;
    case 1:
        ret = deleteVPNService();
        break;
    default:
        break;
    }

    if(ret < 0)
    {
        goto ERROR;
    }


    flag = SCPreferencesCommitChanges(g_prefs);
    if(flag == FALSE)
    {
        qWarning("Could not commit preferences with service.");
        goto ERROR;
    }

    flag = SCPreferencesApplyChanges(g_prefs);
    if(flag == FALSE)
    {
        qWarning("Could not apply changes with service.");
        goto ERROR;
    }

    SCPreferencesUnlock(g_prefs);
    return 0;

ERROR:
    SCPreferencesUnlock(g_prefs);
    return -1;
}

int L2TP::createVPNService()
{
    const NSString *networkServiceName = @VPN_NAME;

    NSString *serverAddress = [NSString stringWithUTF8String:m_server.c_str()];
    NSString *userName = [NSString stringWithUTF8String:m_userName.c_str()];
    NSString *userPassword = [NSString stringWithUTF8String:m_password.c_str()];
    Boolean flag = false;

    // L2TP on top of IPv4
    SCNetworkInterfaceRef bottomInterface = SCNetworkInterfaceCreateWithInterface(kSCNetworkInterfaceIPv4, kSCNetworkInterfaceTypeL2TP);
    // PPP on top of L2TP
    SCNetworkInterfaceRef topInterface = SCNetworkInterfaceCreateWithInterface(bottomInterface, kSCNetworkInterfaceTypePPP);

    SCNetworkServiceRef service = SCNetworkServiceCreate(g_prefs, topInterface);
    flag = SCNetworkServiceSetName(service,  (CFStringRef)networkServiceName);
    if(flag == FALSE)
    {
        qWarning("The service name wasn't saved, because an error occurred.");
        return -1;
    }

    g_serviceID = SCNetworkServiceGetServiceID(service);
    NSString *serviceID = (NSString *)g_serviceID;
    qDebug("Created service:%s", [serviceID UTF8String]);

    CFRelease(topInterface);
    CFRelease(bottomInterface);
    topInterface = NULL;
    bottomInterface = NULL;

    topInterface = SCNetworkServiceGetInterface(service);
    flag = SCNetworkInterfaceSetConfiguration(topInterface, l2tpPPPConfig(serviceID, serverAddress, userName));

    if(flag == TRUE)
    {
        qDebug("Successfully configured PPP interface of services.");
    }
    else
    {
        qWarning("Could not configure PPP interface for services.");
        return -1;
    }

    flag = SCNetworkInterfaceSetExtendedConfiguration(topInterface, CFSTR("IPSec"), l2tpIPSecConfig(serviceID));
    if(flag == TRUE)
    {
        qDebug("Successfully configured IPSec on PPP interface for service.");
    }
    else
    {
        qWarning("Could not configured IPSec on PPP interface for service.");
        return -1;
    }

    flag = SCNetworkServiceEstablishDefaultConfiguration(service);
    if(flag == FALSE)
    {
        qWarning("Could not establish a default service configuration.");
        return -1;
    }

    SCNetworkSetRef networkSet = SCNetworkSetCopyCurrent(g_prefs);
    flag = SCNetworkSetAddService(networkSet, service);
    if(flag == false)
    {
        if(SCError() == 1005)
        {
            qWarning("Skipping VPN Services and because it already exists.");
        }
        else
        {
            qWarning("Failed to add new VPN service.");
        }
        return -1;
    }

    SCNetworkProtocolRef protocol = SCNetworkServiceCopyProtocol(service, kSCNetworkProtocolTypeIPv4);
    if(!protocol)
    {
        qWarning("Could not fetch IPv4 protocol");
        return -1;
    }

    flag = SCNetworkProtocolSetConfiguration(protocol, l2tpIPv4Config());
    if(flag == FALSE)
    {
        qWarning("Could not configure IPv4 protocol.");
        return -1;
    }


    return 0;
}

int L2TP::deleteVPNService()
{
    Boolean flag = false;

    SCNetworkSetRef networkSet = SCNetworkSetCopyCurrent(g_prefs);
    CFArrayRef services = SCNetworkSetCopyServices(networkSet);
    for(CFIndex i=0; i<CFArrayGetCount(services);  i++)
    {
        SCNetworkServiceRef service = (SCNetworkServiceRef)CFArrayGetValueAtIndex(services, i);
        NSString *serviceName = (NSString *)SCNetworkServiceGetName(service);
        if(serviceName == nil || [serviceName length] == 0)
        {
            qWarning("SCNetworkServiceGetName failed.");
            continue;
        }

        if([serviceName compare: @VPN_NAME] != NSOrderedSame)
        {
            continue;
        }

        flag = SCNetworkServiceRemove(service);
        if(flag == TRUE)
        {
            qDebug("Successfully deleted VPN service, %s", [serviceName UTF8String]);
        }
        else
        {
            qWarning("Could not remove VPN service, %s", [serviceName UTF8String]);
            continue;
        }
    }

    return 0;
}

int L2TP::existVPNService()
{
    getAuthorization();
    CFArrayRef services = SCNetworkServiceCopyAll(g_prefs);
    CFIndex servicesCount = CFArrayGetCount(services);
    qDebug("Current service count is %ld", servicesCount);

    for(CFIndex i=0; i<servicesCount;  i++)
    {
        SCNetworkServiceRef service = (SCNetworkServiceRef)CFArrayGetValueAtIndex(services, i);
        NSString *serviceName = (NSString *)SCNetworkServiceGetName(service);
        if(serviceName == nil || [serviceName length] == 0)
        {
            continue;
        }

        if([serviceName compare: @VPN_NAME] != NSOrderedSame)
        {
            continue;
        }

        g_serviceID = SCNetworkServiceGetServiceID(service);

        qDebug("Already exist the VPN service, %s", [serviceName UTF8String]);
        return 0;
    }

    return -1;
}

CFDictionaryRef l2tpPPPConfig(const NSString *serviceID, const NSString *serverAddress, const NSString *username)
{
    CFStringRef keys[4] = {NULL, NULL, NULL, NULL};
    CFStringRef vals[4] = {NULL, NULL, NULL, NULL};
    CFIndex count= 0;

    keys[count] = kSCPropNetPPPCommRemoteAddress;
    vals[count++] = (CFStringRef)serverAddress;

    keys[count] = kSCPropNetPPPAuthName;
    vals[count++] = (CFStringRef)username;

    keys[count] = kSCPropNetPPPAuthPassword;
    vals[count++] = (CFStringRef)serviceID;

    keys[count] = kSCPropNetPPPAuthPasswordEncryption;
    vals[count++] = kSCValNetPPPAuthPasswordEncryptionKeychain;

    return CFDictionaryCreate(NULL, (const void **)&keys, (const void **)&vals, count, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}

CFDictionaryRef l2tpIPSecConfig(const NSString *serviceID)
{
    CFStringRef keys[3] = {NULL, NULL, NULL};
    CFStringRef vals[3] = {NULL, NULL, NULL};
    CFIndex count = 0;

    keys[count] = kSCPropNetIPSecAuthenticationMethod;
    vals[count++] = kSCValNetIPSecAuthenticationMethodSharedSecret;

    keys[count] = kSCPropNetIPSecSharedSecretEncryption;
    vals[count++] = kSCValNetAirPortAuthPasswordEncryptionKeychain;

    keys[count] = kSCPropNetIPSecSharedSecret;
    vals[count++] = (CFStringRef)[NSString stringWithFormat:@"%@.SS", serviceID];

    return CFDictionaryCreate(NULL, (const void **)&keys, (const void **)&vals, count, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}

CFDictionaryRef l2tpIPv4Config()
{
    CFStringRef keys[5] = {NULL, NULL, NULL, NULL, NULL};
    CFStringRef vals[5] = {NULL, NULL, NULL, NULL, NULL};
    CFIndex count = 0;

    keys[count] = kSCPropNetIPv4ConfigMethod;
    vals[count++] = kSCValNetIPv4ConfigMethodPPP;

    int one = 1;
    keys[count] = kSCPropNetOverridePrimary;
    vals[count++] = (CFStringRef)CFNumberCreate(NULL, kCFNumberIntType, &one);

    return CFDictionaryCreate(NULL, (const void **)&keys, (const void **)&vals, count, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}


int getAuthorization()
{
    if(g_prefs == nil)
    {
#if 1
        qDebug("Begin initiate access to the pre-system set of configuration preferences.");
        AuthorizationRef auth = NULL;
        AuthorizationFlags rootFlags = kAuthorizationFlagDefaults | kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize;
        OSStatus authErr = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, rootFlags, &auth);
        if(authErr != errAuthorizationSuccess)
        {
            qWarning("Authorization create fail.");
            return -1;
        }

        g_prefs = SCPreferencesCreateWithAuthorization(NULL, CFSTR(VPN_NAME), NULL, auth);
#else
        g_prefs = SCPreferencesCreate(NULL, CFSTR(VPN_NAME), NULL);
#endif
    }
    return 0;
}

