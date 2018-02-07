//
//  ViewController.m
//  VPNSample2
//
//  Created by  dingxiuwei on 2017/9/5.
//  Copyright © 2017年  dingxiuwei. All rights reserved.
//

#import "ViewController.h"

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <Security/SecKeychain.h>
#import <NetworkExtension/NetworkExtension.h>

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    {
        //@autoreleasepool {
        //}
        
        const NSString* networkServiceName = @"test-vpn123";
        const NSString* serverAddress = @"192.168.10.10";
        const NSString* username = @"dxw";
        const NSString* userPassword = @"123456";
        const NSString* ipsecPassword = @"123456";
        
        //        [[NEVPNManager sharedManager] loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {


        //            SCPreferencesRef prefs = SCPreferencesCreate(NULL, CFSTR("sampleApp"), NULL);
        AuthorizationRef auth = NULL;
        AuthorizationFlags rootFlags = kAuthorizationFlagDefaults
                |  kAuthorizationFlagExtendRights
                |  kAuthorizationFlagInteractionAllowed
                |  kAuthorizationFlagPreAuthorize;
        OSStatus authErr = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, rootFlags, &auth);
        SCPreferencesRef prefs = SCPreferencesCreateWithAuthorization(NULL, CFSTR("sampleApp"), NULL, auth);

        if (SCPreferencesLock(prefs, TRUE)) {
            printf("Gained superhuman rights.\n");
        }
        else {
            printf("Sorry, without superuser privileges I won't be able " \
                   "to add any VPN interfaces.\n");
            return;
        }

        SCNetworkInterfaceRef bottomInterface = SCNetworkInterfaceCreateWithInterface(
                    kSCNetworkInterfaceIPv4, kSCNetworkInterfaceTypeL2TP);
        SCNetworkInterfaceRef topInterface = SCNetworkInterfaceCreateWithInterface(
                    bottomInterface, kSCNetworkInterfaceTypePPP);

        SCNetworkServiceRef service = SCNetworkServiceCreate(prefs, topInterface);
        SCNetworkServiceSetName(service, (__bridge CFStringRef)networkServiceName);
        NSString *serviceID = (__bridge NSString *)(SCNetworkServiceGetServiceID(
                                                        service));

        printf("Created service: %s\n", [serviceID UTF8String]);

        CFRelease(topInterface);
        CFRelease(bottomInterface);
        topInterface = NULL;
        bottomInterface = NULL;

        topInterface = SCNetworkServiceGetInterface(service);
        if (SCNetworkInterfaceSetConfiguration(topInterface,
                                               L2TPPPPConfig(serviceID, serverAddress, username))) {
            printf("Successfully configured PPP interface of service.\n");
        }
        else {
            printf("Error: Could not configure PPP interface for service.\n");
            return ;
        }

        if (SCNetworkInterfaceSetExtendedConfiguration(topInterface,
                                                       CFSTR("IPSec"), L2TPIPSecConfig(serviceID))) {
            printf("Successfully configured IPSec on PPP interface " \
                   "for service.\n");
        }
        else {
            printf("Error: Could not configure IPSec on PPP interface " \
                   "for service.\n");
            return ;
        }

        if (!SCNetworkServiceEstablishDefaultConfiguration(service)) {
            printf("Error: Could not establish a default service " \
                   "configuration.\n");
            return ;
        }

        SCNetworkSetRef networkSet = SCNetworkSetCopyCurrent(prefs);
        if (!networkSet) {
            printf("Error: Could not fetch current network set.\n");
            return ;
        }

        if (!SCNetworkSetAddService (networkSet, service)) {
            if (SCError() == 1005) {
                printf("Skipping VPN Service add because it " \
                       "already exists.\n");
                return ;
            }
            else {
                printf("Failed to add new VPN service.\n");
            }
        }

        SCNetworkProtocolRef protocol = SCNetworkServiceCopyProtocol(service,
                                                                     kSCNetworkProtocolTypeIPv4);
        if (!protocol) {
            printf("Error: Could not fetch IPv4 protocol.\n");
            return ;
        }

        if (!SCNetworkProtocolSetConfiguration(protocol, L2TPIPv4Config())) {
            printf("Error: Could not configure IPv4 protocol.\n");
            return ;
        }

        if (!SCPreferencesCommitChanges(prefs)) {
            printf("Error: Could not commit preferences with service.\n");
            return ;
        }

        createPasswordKeyChainItem(networkServiceName, serviceID, username,
                                   userPassword);
        createSharedSecretKeyChainItem(networkServiceName, serviceID, username,
                                       ipsecPassword);

        if (!SCPreferencesApplyChanges(prefs)) {
            printf("Error: Could not apply changes with service.\n");
            return ;
        }

        SCPreferencesUnlock(prefs);




        //        }];
        
    }
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

CFDictionaryRef L2TPPPPConfig(const NSString* serviceID,
                              const NSString* serverAddress, const NSString* username) {
    CFStringRef keys[4] = { NULL, NULL, NULL, NULL };
    CFStringRef vals[4] = { NULL, NULL, NULL, NULL };
    CFIndex count = 0;
    
    keys[count] = kSCPropNetPPPCommRemoteAddress;
    vals[count++] = (__bridge CFStringRef)serverAddress;
    
    keys[count] = kSCPropNetPPPAuthName;
    vals[count++] = (__bridge CFStringRef)username;
    
    keys[count] = kSCPropNetPPPAuthPassword;
    vals[count++] = (__bridge CFStringRef)serviceID;
    
    keys[count] = kSCPropNetPPPAuthPasswordEncryption;
    vals[count++] = kSCValNetPPPAuthPasswordEncryptionKeychain;
    
    return CFDictionaryCreate(NULL, (const void **)&keys, (const void **)&vals,
                              count, &kCFTypeDictionaryKeyCallBacks,
                              &kCFTypeDictionaryValueCallBacks);
}


CFDictionaryRef L2TPIPSecConfig(const NSString* serviceID) {
    CFStringRef keys[3] = { NULL, NULL, NULL };
    CFStringRef vals[3] = { NULL, NULL, NULL };
    CFIndex count = 0;
    
    keys[count] = kSCPropNetIPSecAuthenticationMethod;
    vals[count++] = kSCValNetIPSecAuthenticationMethodSharedSecret;
    
    keys[count] = kSCPropNetIPSecSharedSecretEncryption;
    vals[count++] = kSCValNetIPSecSharedSecretEncryptionKeychain;
    
    keys[count] = kSCPropNetIPSecSharedSecret;
    vals[count++] = (__bridge CFStringRef)[NSString stringWithFormat:@"%@.SS",
            serviceID];
    
    return CFDictionaryCreate(NULL, (const void **)&keys,
                              (const void **)&vals, count, &kCFTypeDictionaryKeyCallBacks,
                              &kCFTypeDictionaryValueCallBacks);
}


CFDictionaryRef L2TPIPv4Config() {
    CFStringRef keys[5] = { NULL, NULL, NULL, NULL, NULL };
    CFStringRef vals[5] = { NULL, NULL, NULL, NULL, NULL };
    CFIndex count = 0;
    
    keys[count] = kSCPropNetIPv4ConfigMethod;
    vals[count++] = kSCValNetIPv4ConfigMethodPPP;
    
    int one = 1;
    keys[count] = kSCPropNetOverridePrimary;
    
    vals[count++] = (CFStringRef)CFNumberCreate(NULL, kCFNumberIntType, &one);
    
    return CFDictionaryCreate(NULL, (const void **)&keys,
                              (const void **)&vals, count, &kCFTypeDictionaryKeyCallBacks,
                              &kCFTypeDictionaryValueCallBacks);
}


const char * trustedAppPaths[] = {
    "/System/Library/Frameworks/SystemConfiguration.framework/Versions/A/Helpers/SCHelper",
    "/System/Library/PreferencePanes/Network.prefPane/Contents/XPCServices/com.apple.preference.network.remoteservice.xpc",
    "/System/Library/CoreServices/SystemUIServer.app",
    "/usr/sbin/pppd",
    "/usr/sbin/racoon",
    "/usr/libexec/configd",
    
};

NSArray* trustedApps() {
    NSMutableArray *apps = [NSMutableArray array];
    SecTrustedApplicationRef app;
    OSStatus err;
    
    for (int i = 0; i < (sizeof(trustedAppPaths) / sizeof(*trustedAppPaths)); i++) {
        err = SecTrustedApplicationCreateFromPath(trustedAppPaths[i], &app);
        if (err == errSecSuccess) {
        }
        else {
            printf("SecTrustedApplicationCreateFromPath failed.\n");
        }
        
        [apps addObject:(__bridge id)app];
    }
    
    return apps;
}


int createKeyChainItem(const NSString* label, const NSString* service,
                       const NSString* account, const NSString* description,
                       const NSString* password) {
    
    OSStatus status;
    
    const char *labelUTF8 = [label UTF8String];
    const char *serviceUTF8 = [service UTF8String];
    const char *accountUTF8 = [account UTF8String];
    const char *descriptionUTF8 = [description UTF8String];
    const char *passwordUTF8 = [password UTF8String];
    
    SecKeychainRef keychain = NULL;
    status = SecKeychainCopyDomainDefault(kSecPreferencesDomainSystem, &keychain);
    if (status == errSecSuccess) {
        printf("Succeeded opening System Keychain");
    }
    else {
        printf("Could not obtain System Keychain.\n");
        return 1;
    }
    
    printf("Unlocking System Keychain\n");
    status = SecKeychainUnlock(keychain, 0, NULL, FALSE);
    if (status == errSecSuccess) {
        printf("Succeeded unlocking System Keychain");
    }
    else {
        printf("Could not unlock System Keychain.\n");
        return 1;
    }
    
    SecKeychainItemRef item = nil;
    
    SecAccessRef access = nil;
    status = SecAccessCreate(CFSTR("Some VPN Test"),
                             (__bridge CFArrayRef)(trustedApps()), &access);
    
    if(status == noErr) {
        printf("Created empty Keychain access object.\n");
    }
    else {
        printf("Could not unlock System Keychain.\n");
        return 1;
    }
    
    //    status = SecKeychainAddGenericPassword (
    //                                            NULL,            // default keychain
    //                                            (int)strlen(serviceUTF8),              // length of service name
    //                                            serviceUTF8,    // service name
    //                                            (int)strlen(accountUTF8),              // length of account name
    //                                            accountUTF8,    // account name
    //                                            (int)strlen(passwordUTF8),  // length of password
    //                                            passwordUTF8,        // pointer to password data
    //                                            NULL             // the item reference
    //                                            );
    
    SecKeychainAttribute attrs[] = {
        {kSecLabelItemAttr, (int)strlen(labelUTF8), (char *)labelUTF8},
        {kSecAccountItemAttr, (int)strlen(accountUTF8), (char *)accountUTF8},
        {kSecServiceItemAttr, (int)strlen(serviceUTF8), (char *)serviceUTF8},
        {kSecDescriptionItemAttr, (int)strlen(descriptionUTF8),
         (char *)descriptionUTF8},
    };
    
    SecKeychainAttributeList attributes = {sizeof(attrs) / sizeof(attrs[0]), attrs};
    
    status = SecKeychainItemCreateFromContent(kSecGenericPasswordItemClass,
                                              &attributes, (int)strlen(passwordUTF8), passwordUTF8, keychain,
                                              access, &item);
    
    if(status == noErr) {
        printf("Successfully created Keychain Item.\n");
    }
    else {
        printf("Creating Keychain item failed.\n");
        return 1;
    }
    
    return 0;
}


int createPasswordKeyChainItem(const NSString* label, const NSString* service,
                               const NSString* account, const NSString* password) {
    return createKeyChainItem(label, service, account, @"PPP Password",
                              password);
}


int createSharedSecretKeyChainItem(const NSString* label, const NSString* service,
                                   const NSString* account, const NSString* password) {
    service = [NSString stringWithFormat:@"%@.SS", service];
    return createKeyChainItem(label, service, account, @"IPSec Shared Secret",
                              password);
}




@end
