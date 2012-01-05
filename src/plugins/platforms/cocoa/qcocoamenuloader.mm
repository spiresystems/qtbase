/****************************************************************************
**
** Copyright (C) 2012 Nokia Corporation and/or its subsidiary(-ies).
** All rights reserved.
** Contact: Nokia Corporation (qt-info@nokia.com)
**
** This file is part of the plugins of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:LGPL$
** GNU Lesser General Public License Usage
** This file may be used under the terms of the GNU Lesser General Public
** License version 2.1 as published by the Free Software Foundation and
** appearing in the file LICENSE.LGPL included in the packaging of this
** file. Please review the following information to ensure the GNU Lesser
** General Public License version 2.1 requirements will be met:
** http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html.
**
** In addition, as a special exception, Nokia gives you certain additional
** rights. These rights are described in the Nokia Qt LGPL Exception
** version 1.1, included in the file LGPL_EXCEPTION.txt in this package.
**
** GNU General Public License Usage
** Alternatively, this file may be used under the terms of the GNU General
** Public License version 3.0 as published by the Free Software Foundation
** and appearing in the file LICENSE.GPL included in the packaging of this
** file. Please review the following information to ensure the GNU General
** Public License version 3.0 requirements will be met:
** http://www.gnu.org/copyleft/gpl.html.
**
** Other Usage
** Alternatively, this file may be used in accordance with the terms and
** conditions contained in a signed written agreement between you and Nokia.
**
**
**
**
**
** $QT_END_LICENSE$
**
****************************************************************************/

#include "qcocoamenuloader.h"

#include "qmenu_mac.h"
#include "qcocoahelpers.h"

#include <QtCore/private/qcore_mac_p.h>
#include <QtCore/qcoreapplication.h>
#include <QtCore/qdir.h>
#include <QtCore/qstring.h>
#include <QtCore/qdebug.h>

QT_FORWARD_DECLARE_CLASS(QCFString)
QT_FORWARD_DECLARE_CLASS(QString)

#ifndef QT_NO_TRANSLATION
    QT_BEGIN_NAMESPACE
    extern QString qt_mac_applicationmenu_string(int type);
    QT_END_NAMESPACE
#endif

QT_USE_NAMESPACE

/*
    Loads and instantiates the main app menu from the menu nib file(s).

    The main app menu contains the Quit, Hide  About, Preferences entries, and
    The reason for having the nib file is that those can not be created
    programmatically. To ease deployment the nib files are stored in Qt resources
    and written to QDir::temp() before loading. (Earlier Qt versions used
    to require having the nib file in the QtGui framework.)
*/
void qt_mac_loadMenuNib(QT_MANGLE_NAMESPACE(QCocoaMenuLoader) *qtMenuLoader)
{
    // Create qt_menu.nib dir in temp.
    QDir temp = QDir::temp();
    temp.mkdir("qt_menu.nib");
    QString nibDir = temp.canonicalPath() + QLatin1String("/") + QLatin1String("qt_menu.nib/");
    if (!QDir(nibDir).exists()) {
        qWarning("qt_mac_loadMenuNib: could not create nib directory in temp");
        return;
    }

    // Copy nib files from resources to temp.
    QDir nibResource(":/trolltech/mac/qt_menu.nib/");
    if (!nibResource.exists()) {
        qWarning("qt_mac_loadMenuNib: could not load nib from resources");
        return;
    }
    foreach (const QFileInfo &file, nibResource.entryInfoList()) {
        QFile::copy(file.absoluteFilePath(), nibDir + QLatin1String("/") + file.fileName());
    }

    // Load and instantiate nib file from temp
    NSURL *nibUrl = [NSURL fileURLWithPath : const_cast<NSString *>(reinterpret_cast<const NSString *>(QCFString::toCFStringRef(nibDir)))];
    [nibUrl autorelease];
    NSNib *nib = [[NSNib alloc] initWithContentsOfURL : nibUrl];
    [nib autorelease];
    if(!nib) {
        qWarning("qt_mac_loadMenuNib: could not load nib from  temp");
        return;
    }
    bool ok = [nib instantiateNibWithOwner : qtMenuLoader topLevelObjects : nil];
    if (!ok) {
        qWarning("qt_mac_loadMenuNib: could not instantiate nib");
    }
}



@implementation QT_MANGLE_NAMESPACE(QCocoaMenuLoader)

- (void)awakeFromNib
{
    servicesItem = [[appMenu itemWithTitle:@"Services"] retain];
    hideAllOthersItem = [[appMenu itemWithTitle:@"Hide Others"] retain];
    showAllItem = [[appMenu itemWithTitle:@"Show All"] retain];

    // Get the names in the nib to match the app name set by Qt.
    const NSString *appName = reinterpret_cast<const NSString*>(QCFString::toCFStringRef(qt_mac_applicationName()));
    [quitItem setTitle:[[quitItem title] stringByReplacingOccurrencesOfString:@"NewApplication"
                                                                   withString:const_cast<NSString *>(appName)]];
    [hideItem setTitle:[[hideItem title] stringByReplacingOccurrencesOfString:@"NewApplication"
                                                                   withString:const_cast<NSString *>(appName)]];
    [aboutItem setTitle:[[aboutItem title] stringByReplacingOccurrencesOfString:@"NewApplication"
                                                                   withString:const_cast<NSString *>(appName)]];
    [appName release];
    // Disable the items that don't do anything. If someone associates a QAction with them
    // They should get synced back in.
    [preferencesItem setEnabled:NO];
    [preferencesItem setHidden:YES];
    [aboutItem setEnabled:NO];
    [aboutItem setHidden:YES];
}

- (void)ensureAppMenuInMenu:(NSMenu *)menu
{
    // The application menu is the menu in the menu bar that contains the
    // 'Quit' item. When changing menu bar (e.g when switching between
    // windows with different menu bars), we never recreate this menu, but
    // instead pull it out the current menu bar and place into the new one:
    NSMenu *mainMenu = [NSApp mainMenu];
    if ([NSApp mainMenu] == menu)
        return; // nothing to do (menu is the current menu bar)!

#ifndef QT_NAMESPACE
    Q_ASSERT(mainMenu);
#endif
    // Grab the app menu out of the current menu.
    int numItems = [mainMenu numberOfItems];
    NSMenuItem *oldAppMenuItem = 0;
    for (int i = 0; i < numItems; ++i) {
        NSMenuItem *item = [mainMenu itemAtIndex:i];
        if ([item submenu] == appMenu) {
            oldAppMenuItem = item;
            [oldAppMenuItem retain];
            [mainMenu removeItemAtIndex:i];
            break;
        }
    }

    if (oldAppMenuItem) {
        [oldAppMenuItem setSubmenu:nil];
        [oldAppMenuItem release];
        NSMenuItem *appMenuItem = [[NSMenuItem alloc] initWithTitle:@"Apple"
            action:nil keyEquivalent:@""];
        [appMenuItem setSubmenu:appMenu];
        [menu insertItem:appMenuItem atIndex:0];
    }
}

- (void)removeActionsFromAppMenu
{
    for (NSMenuItem *item in [appMenu itemArray])
        [item setTag:nil];
}

- (void)dealloc
{
    [servicesItem release];
    [hideAllOthersItem release];
    [showAllItem release];

    [lastAppSpecificItem release];
    [theMenu release];
    [appMenu release];
    [super dealloc];
}

- (NSMenu *)menu
{
    return [[theMenu retain] autorelease];
}

- (NSMenu *)applicationMenu
{
    return [[appMenu retain] autorelease];
}

- (NSMenuItem *)quitMenuItem
{
    return [[quitItem retain] autorelease];
}

- (NSMenuItem *)preferencesMenuItem
{
    return [[preferencesItem retain] autorelease];
}

- (NSMenuItem *)aboutMenuItem
{
    return [[aboutItem retain] autorelease];
}

- (NSMenuItem *)aboutQtMenuItem
{
    return [[aboutQtItem retain] autorelease];
}

- (NSMenuItem *)hideMenuItem
{
    return [[hideItem retain] autorelease];
}

- (NSMenuItem *)appSpecificMenuItem
{
    // Create an App-Specific menu item, insert it into the menu and return
    // it as an autorelease item.
    NSMenuItem *item = [[NSMenuItem alloc] init];

    NSInteger location;
    if (lastAppSpecificItem == nil) {
        location = [appMenu indexOfItem:aboutQtItem];
    } else {
        location = [appMenu indexOfItem:lastAppSpecificItem];
        [lastAppSpecificItem release];
    }
    lastAppSpecificItem = item;  // Keep track of this for later (i.e., don't release it)
    [appMenu insertItem:item atIndex:location + 1];

    return [[item retain] autorelease];
}

- (BOOL) acceptsFirstResponder
{
    return YES;
}

- (void)terminate:(id)sender
{
    [NSApp terminate:sender];
}

- (void)orderFrontStandardAboutPanel:(id)sender
{
    [NSApp orderFrontStandardAboutPanel:sender];
}

- (void)hideOtherApplications:(id)sender
{
    [NSApp hideOtherApplications:sender];
}

- (void)unhideAllApplications:(id)sender
{
    [NSApp unhideAllApplications:sender];
}

- (void)hide:(id)sender
{
    [NSApp hide:sender];
}

- (void)qtUpdateMenubar
{
    QCocoaMenuBar::macUpdateMenuBarImmediatly();
}

- (void)qtTranslateApplicationMenu
{

    qDebug() << "qtTranslateApplicationMenu";

#ifndef QT_NO_TRANSLATION
    [servicesItem setTitle: qt_mac_QStringToNSString(qt_mac_applicationmenu_string(0))];
    [hideItem setTitle: qt_mac_QStringToNSString(qt_mac_applicationmenu_string(1).arg(qt_mac_applicationName()))];
    [hideAllOthersItem setTitle: qt_mac_QStringToNSString(qt_mac_applicationmenu_string(2))];
    [showAllItem setTitle: qt_mac_QStringToNSString(qt_mac_applicationmenu_string(3))];
    [preferencesItem setTitle: qt_mac_QStringToNSString(qt_mac_applicationmenu_string(4))];
    [quitItem setTitle: qt_mac_QStringToNSString(qt_mac_applicationmenu_string(5).arg(qt_mac_applicationName()))];
    [aboutItem setTitle: qt_mac_QStringToNSString(qt_mac_applicationmenu_string(6).arg(qt_mac_applicationName()))];
#endif
}

- (IBAction)qtDispatcherToQAction:(id)sender
{
    //
    //QScopedLoopLevelCounter loopLevelCounter(QApplicationPrivate::instance()->threadData);
    NSMenuItem *item = static_cast<NSMenuItem *>(sender);
    if (QAction *action = reinterpret_cast<QAction *>([item tag])) {
        action->trigger();
    } else if (item == quitItem) {
        // We got here because someone was once the quitItem, but it has been
        // abandoned (e.g., the menubar was deleted). In the meantime, just do
        // normal QApplication::quit().
        qApp->quit();
    }
}

 - (void)orderFrontCharacterPalette:(id)sender
 {
     [NSApp orderFrontCharacterPalette:sender];
 }
@end
