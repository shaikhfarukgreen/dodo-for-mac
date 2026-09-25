import AppKit
import WebKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate { NSApp.delegate as! AppDelegate }

    private var windowControllers: [BrowserWindowController] = []
    private var settingsController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.build()
        openNewWindow(with: Settings.shared.startURL)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openNewWindow(with: Settings.shared.startURL)
        }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            openNewWindow(with: url)
        }
    }

    // MARK: - Windows

    @discardableResult
    func openNewWindow(with url: URL?) -> BrowserWindowController {
        let controller = BrowserWindowController(onClose: { [weak self] in self?.remove($0) })
        track(controller)
        if let url = url {
            controller.load(url)
        }
        return controller
    }

    /// Creates a window for a page-initiated popup. WebKit loads the request itself.
    func openPopupWindow(configuration: WKWebViewConfiguration) -> BrowserWindowController {
        let controller = BrowserWindowController(configuration: configuration, isPopup: true, onClose: { [weak self] in self?.remove($0) })
        track(controller)
        return controller
    }

    private func track(_ controller: BrowserWindowController) {
        windowControllers.append(controller)
        if let window = controller.window {
            if let current = NSApp.keyWindow, current.frame.origin != .zero, windowControllers.count > 1 {
                window.setFrameTopLeftPoint(NSPoint(x: current.frame.minX + 24, y: current.frame.maxY - 24))
            }
            controller.showWindow(nil)
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func remove(_ controller: BrowserWindowController) {
        windowControllers.removeAll { $0 === controller }
    }

    private var activeBrowser: BrowserWindowController? {
        NSApp.keyWindow?.windowController as? BrowserWindowController
            ?? NSApp.mainWindow?.windowController as? BrowserWindowController
    }

    // MARK: - Menu actions

    @objc func newWindow(_ sender: Any?) {
        openNewWindow(with: URLNormalizer.url(from: Settings.shared.homeURL))
    }

    @objc func showSettings(_ sender: Any?) {
        if settingsController == nil {
            settingsController = SettingsWindowController()
        } else {
            settingsController?.reload()
        }
        settingsController?.showWindow(nil)
        settingsController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc func clearWebsiteData(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "Clear all website data?"
        alert.informativeText = "This signs you out of every site and removes cookies, cache and local storage."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let store = WebViewFactory.dataStore
        store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { [weak self] in
            self?.windowControllers.forEach { $0.reloadPage(nil) }
        }
    }

    @objc func openHelp(_ sender: Any?) {
        if let url = URL(string: "https://github.com/shaikhfarukgreen/dodo-for-mac#readme") {
            NSWorkspace.shared.open(url)
        }
    }
}
