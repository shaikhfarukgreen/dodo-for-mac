import AppKit

/// Builds the menu bar in code (no nib), including the standard Edit menu so ⌘C/⌘V work in web forms.
enum MainMenu {
    static func build() -> NSMenu {
        let mainMenu = NSMenu()
        let appName = ProcessInfo.processInfo.processName == "DodoMac" ? "Dodo for Mac" : ProcessInfo.processInfo.processName

        // App menu
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(item("Settings…", #selector(AppDelegate.showSettings(_:)), ","))
        appMenu.addItem(item("Clear Website Data…", #selector(AppDelegate.clearWebsiteData(_:)), ""))
        appMenu.addItem(.separator())
        let services = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu()
        services.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        appMenu.addItem(services)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        addSubmenu(appMenu, title: appName, to: mainMenu)

        // File menu
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(item("New Window", #selector(AppDelegate.newWindow(_:)), "n"))
        fileMenu.addItem(item("Open Location…", #selector(BrowserWindowController.focusAddressBar(_:)), "l"))
        fileMenu.addItem(.separator())
        fileMenu.addItem(item("Copy Page Address", #selector(BrowserWindowController.copyPageURL(_:)), "c", [.command, .shift]))
        fileMenu.addItem(item("Open in Default Browser", #selector(BrowserWindowController.openInDefaultBrowser(_:)), ""))
        fileMenu.addItem(.separator())
        fileMenu.addItem(item("Close Window", #selector(NSWindow.performClose(_:)), "w"))
        addSubmenu(fileMenu, title: "File", to: mainMenu)

        // Edit menu
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        addSubmenu(editMenu, title: "Edit", to: mainMenu)

        // View menu
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(item("Reload Page", #selector(BrowserWindowController.reloadPage(_:)), "r"))
        viewMenu.addItem(item("Reload From Origin", #selector(BrowserWindowController.reloadFromOrigin(_:)), "r", [.command, .option]))
        viewMenu.addItem(.separator())
        viewMenu.addItem(item("Zoom In", #selector(BrowserWindowController.zoomIn(_:)), "+"))
        viewMenu.addItem(item("Zoom Out", #selector(BrowserWindowController.zoomOut(_:)), "-"))
        viewMenu.addItem(item("Actual Size", #selector(BrowserWindowController.actualSize(_:)), "0"))
        viewMenu.addItem(.separator())
        let fullScreen = viewMenu.addItem(withTitle: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fullScreen.keyEquivalentModifierMask = [.command, .control]
        addSubmenu(viewMenu, title: "View", to: mainMenu)

        // History menu
        let historyMenu = NSMenu(title: "History")
        historyMenu.addItem(item("Back", #selector(BrowserWindowController.goBack(_:)), "["))
        historyMenu.addItem(item("Forward", #selector(BrowserWindowController.goForward(_:)), "]"))
        historyMenu.addItem(item("Home", #selector(BrowserWindowController.goHome(_:)), "h", [.command, .shift]))
        addSubmenu(historyMenu, title: "History", to: mainMenu)

        // Window menu
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        addSubmenu(windowMenu, title: "Window", to: mainMenu)
        NSApp.windowsMenu = windowMenu

        // Help menu
        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(item("Dodo for Mac Help", #selector(AppDelegate.openHelp(_:)), "?"))
        addSubmenu(helpMenu, title: "Help", to: mainMenu)
        NSApp.helpMenu = helpMenu

        return mainMenu
    }

    /// Items with a nil target travel the responder chain, so browser actions reach the key window's controller.
    private static func item(_ title: String, _ action: Selector, _ key: String, _ modifiers: NSEvent.ModifierFlags = [.command]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        return item
    }

    private static func addSubmenu(_ menu: NSMenu, title: String, to mainMenu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        menu.title = title
        item.submenu = menu
        mainMenu.addItem(item)
    }
}
