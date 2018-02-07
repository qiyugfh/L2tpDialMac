QT -= gui

CONFIG += c++11 console
CONFIG -= app_bundle

# The following define makes your compiler emit warnings if you use
# any feature of Qt which as been marked deprecated (the exact warnings
# depend on your compiler). Please consult the documentation of the
# deprecated API in order to know how to port your code away from it.
DEFINES += QT_DEPRECATED_WARNINGS

# You can also make your code fail to compile if you use deprecated APIs.
# In order to do so, uncomment the following line.
# You can also select to disable deprecated APIs only up to a certain version of Qt.
#DEFINES += QT_DISABLE_DEPRECATED_BEFORE=0x060000    # disables all the APIs deprecated before Qt 6.0.0

SOURCES += main.cpp


HEADERS += l2tp_mac.h


macx {

OBJECTIVE_SOURCES += l2tp_mac.mm

QMAKE_LFLAGS += -F /System/Library/Frameworks/

LIBS += -framework SystemConfiguration
LIBS += -framework CoreFoundation
LIBS += -framework Foundation
LIBS += -framework NetworkExtension
LIBS += -framework Security
LIBS += -framework AppKit
}
