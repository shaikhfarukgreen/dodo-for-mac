import AppKit
import WebKit

final class BrowserWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate, NSTextFieldDelegate {
    let webView: WKWebView

    private let addressField = NSTextField()
    private let navigationControl = NSSegmentedControl()
    private let reloadButton = NSButton()
    private let homeButton = NSButton()
    private let progressBar = NSProgressIndicator()
    private var observations: [NSKeyValueObservation] = []
    private let isPopup: Bool
    private var onClose: ((BrowserWindowController) -> Void)?

    private enum ItemID {
        static let navigation = NSToolbarItem.Identifier("navigation")
        static let reload = NSToolbarItem.Identifier("reload")
        static let home = NSToolbarItem.Identifier("home")
        static let address = NSToolbarItem.Identifier("address")
    }

    /// - Parameters:
    ///   - configuration: pass the configuration WebKit hands to `createWebViewWith` for popups.
    init(configuration: WKWebViewConfiguration? = nil, isPopup: Bool = false, onClose: @escaping (BrowserWindowController) -> Void) {
        self.isPopup = isPopup
        self.onClose = onClose
        self.webView = WebViewFactory.makeWebView(configuration: configuration ?? WebViewFactory.makeConfiguration())

        let size = isPopup ? NSSize(width: 480, height: 800) : NSSize(width: 1280, height: 820)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Dodo for Mac"
        window.minSize = NSSize(width: 360, height: 400)
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.tabbingMode = .automatic
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        if !isPopup {
            window.setFrameAutosaveName("DodoMainWindow")
        }

        super.init(window: window)

        window.delegate = self
        setUpContent()
        setUpToolbar()
        observeWebView()

        webView.navigationDelegate = self
        webView.uiDelegate = self

        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: .browserSettingsChanged, object: nil)

        if window.frame.origin == .zero {
            window.center()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Layout

    private func setUpContent() {
        let container = NSView()
        webView.translatesAutoresizingMaskIntoConstraints = false
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.style = .bar
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 1
        progressBar.controlSize = .small
        progressBar.isHidden = true

        container.addSubview(webView)
        container.addSubview(progressBar)

        let guide = container.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: guide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            progressBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            progressBar.topAnchor.constraint(equalTo: guide.topAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 3),
        ])
        window?.contentView = container
    }

    private func setUpToolbar() {
        navigationControl.segmentCount = 2
        navigationControl.trackingMode = .momentary
        navigationControl.setImage(NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back"), forSegment: 0)
        navigationControl.setImage(NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Forward"), forSegment: 1)
        navigationControl.setWidth(32, forSegment: 0)
        navigationControl.setWidth(32, forSegment: 1)
        navigationControl.target = self
        navigationControl.action = #selector(navigationSegmentClicked(_:))

        configureToolbarButton(reloadButton, symbol: "arrow.clockwise", label: "Reload", action: #selector(reloadOrStop(_:)))
        configureToolbarButton(homeButton, symbol: "house", label: "Home", action: #selector(goHome(_:)))

        addressField.placeholderString = "Enter address or search"
        addressField.bezelStyle = .roundedBezel
        addressField.lineBreakMode = .byTruncatingTail
        addressField.usesSingleLineMode = true
        addressField.cell?.isScrollable = true
        addressField.delegate = self
        addressField.target = self
        addressField.action = #selector(addressEntered(_:))

        let toolbar = NSToolbar(identifier: isPopup ? "PopupToolbar" : "BrowserToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window?.toolbar = toolbar
        if #available(macOS 11.0, *) {
            window?.toolbarStyle = .unified
        }
    }

    private func configureToolbarButton(_ button: NSButton, symbol: String, label: String, action: Selector) {
        button.bezelStyle = .texturedRounded
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        button.imagePosition = .imageOnly
        button.toolTip = label
        button.target = self
        button.action = action
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [ItemID.navigation, ItemID.reload, ItemID.home, ItemID.address]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        switch itemIdentifier {
        case ItemID.navigation:
            item.label = "Back/Forward"
            item.view = navigationControl
        case ItemID.reload:
            item.label = "Reload"
            item.view = reloadButton
        case ItemID.home:
            item.label = "Home"
            item.view = homeButton
        case ItemID.address:
            item.label = "Address"
            item.view = addressField
            // Fixed min/max sizes let the field stretch with the window instead of overflowing into ">>".
            addressField.frame = NSRect(x: 0, y: 0, width: 600, height: 24)
            item.minSize = NSSize(width: 160, height: 24)
            item.maxSize = NSSize(width: 1400, height: 24)
        default:
            return nil
        }
        return item
    }

    // MARK: - State observation

    private func observeWebView() {
        observations = [
            webView.observe(\.title, options: [.initial, .new]) { [weak self] webView, _ in
                let title = webView.title ?? ""
                self?.window?.title = title.isEmpty ? "Dodo for Mac" : title
            },
            webView.observe(\.url, options: [.initial, .new]) { [weak self] webView, _ in
                guard let self = self else { return }
                if self.window?.firstResponder !== self.addressField.currentEditor() {
                    self.addressField.stringValue = webView.url?.absoluteString ?? ""
                }
                if !self.isPopup, let url = webView.url, ["http", "https"].contains(url.scheme ?? "") {
                    Settings.shared.lastURL = url.absoluteString
                }
            },
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] webView, _ in
                self?.navigationControl.setEnabled(webView.canGoBack, forSegment: 0)
            },
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] webView, _ in
                self?.navigationControl.setEnabled(webView.canGoForward, forSegment: 1)
            },
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] webView, _ in
                let symbol = webView.isLoading ? "xmark" : "arrow.clockwise"
                self?.reloadButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: webView.isLoading ? "Stop" : "Reload")
                self?.progressBar.isHidden = !webView.isLoading
            },
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                self?.progressBar.doubleValue = webView.estimatedProgress
            },
        ]
    }

    // MARK: - Actions

    func load(_ url: URL) {
        webView.load(URLRequest(url: url))
    }

    func loadStartPage() {
        if let url = Settings.shared.startURL {
            load(url)
        }
    }

    @objc private func navigationSegmentClicked(_ sender: NSSegmentedControl) {
        if sender.selectedSegment == 0 {
            webView.goBack()
        } else {
            webView.goForward()
        }
    }

    @objc func goBack(_ sender: Any?) { webView.goBack() }
    @objc func goForward(_ sender: Any?) { webView.goForward() }

    @objc func reloadOrStop(_ sender: Any?) {
        if webView.isLoading {
            webView.stopLoading()
        } else {
            reloadPage(sender)
        }
    }

    @objc func reloadPage(_ sender: Any?) {
        if webView.url == nil {
            loadStartPage()
        } else {
            webView.reload()
        }
    }

    @objc func reloadFromOrigin(_ sender: Any?) {
        webView.reloadFromOrigin()
    }

    @objc func goHome(_ sender: Any?) {
        if let url = URLNormalizer.url(from: Settings.shared.homeURL) {
            load(url)
        }
    }

    @objc func focusAddressBar(_ sender: Any?) {
        window?.makeFirstResponder(addressField)
        addressField.currentEditor()?.selectAll(nil)
    }

    /// Resizes the window to an iPhone-like shape, or back to a normal laptop size.
    @objc func togglePhoneSize(_ sender: Any?) {
        guard let window = window, !window.styleMask.contains(.fullScreen) else { return }
        let phone = NSSize(width: 430, height: 900)
        let current = window.contentLayoutRect.size
        let isPhone = abs(current.width - phone.width) < 20
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: isPhone ? NSSize(width: 1280, height: 820) : phone))
        frame.origin = NSPoint(x: window.frame.midX - frame.width / 2, y: window.frame.maxY - frame.height)
        window.setFrame(frame, display: true, animate: true)
    }

    @objc func zoomIn(_ sender: Any?) { webView.pageZoom = min(webView.pageZoom + 0.1, 3) }
    @objc func zoomOut(_ sender: Any?) { webView.pageZoom = max(webView.pageZoom - 0.1, 0.3) }
    @objc func actualSize(_ sender: Any?) { webView.pageZoom = 1 }

    @objc func copyPageURL(_ sender: Any?) {
        guard let url = webView.url else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }

    @objc func openInDefaultBrowser(_ sender: Any?) {
        if let url = webView.url {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func addressEntered(_ sender: NSTextField) {
        guard let url = URLNormalizer.url(from: sender.stringValue) else { return }
        load(url)
        window?.makeFirstResponder(webView)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            addressField.stringValue = webView.url?.absoluteString ?? ""
            window?.makeFirstResponder(webView)
            return true
        }
        return false
    }

    @objc private func settingsChanged() {
        let profile = Settings.shared.activeProfile
        webView.customUserAgent = profile.userAgent
        WebViewFactory.applyProfile(to: webView.configuration)
        reloadPage(nil)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        webView.stopLoading()
        // Stop any playing media before the window goes away.
        webView.loadHTMLString("", baseURL: nil)
        observations.removeAll()
        // Release the controller after AppKit has finished closing the window.
        if let onClose = onClose {
            self.onClose = nil
            DispatchQueue.main.async { onClose(self) }
        }
    }

    // MARK: - Helpers

    fileprivate func showError(_ error: Error) {
        let nsError = error as NSError
        // Cancelled loads and "frame load interrupted" (e.g. a download started) are not real errors.
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
        if nsError.domain == "WebKitErrorDomain" && (nsError.code == 102 || nsError.code == 204) { return }

        let escaped = nsError.localizedDescription
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
        let html = """
        <html><head><meta name="viewport" content="width=device-width, initial-scale=1">
        <style>body{font:-apple-system-body;font-family:-apple-system;color:#666;display:flex;
        align-items:center;justify-content:center;height:90vh;text-align:center;padding:20px}
        @media (prefers-color-scheme: dark){body{background:#1e1e1e;color:#aaa}}</style></head>
        <body><div><h2>Can’t open this page</h2><p>\(escaped)</p></div></body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: - WKNavigationDelegate

extension BrowserWindowController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() else {
            decisionHandler(.allow, preferences)
            return
        }

        // Hand non-web links (mailto:, tel:, app deep links, …) to macOS.
        let webSchemes: Set<String> = ["http", "https", "about", "data", "blob", "file", "javascript"]
        if !webSchemes.contains(scheme) {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel, preferences)
            return
        }

        // ⌘-click opens the link in a new window, like Safari.
        if navigationAction.modifierFlags.contains(.command), navigationAction.navigationType == .linkActivated {
            AppDelegate.shared.openNewWindow(with: url)
            decisionHandler(.cancel, preferences)
            return
        }

        if navigationAction.shouldPerformDownload {
            decisionHandler(.download, preferences)
            return
        }

        preferences.preferredContentMode = Settings.shared.activeProfile.prefersMobileContent ? .mobile : .desktop
        decisionHandler(.allow, preferences)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let response = navigationResponse.response as? HTTPURLResponse,
           let disposition = response.value(forHTTPHeaderField: "Content-Disposition"),
           disposition.lowercased().hasPrefix("attachment") {
            decisionHandler(.download)
            return
        }
        decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = DownloadManager.shared
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = DownloadManager.shared
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showError(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        if nsError.code != NSURLErrorCancelled {
            NSLog("Navigation failed: \(error)")
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}

// MARK: - WKUIDelegate

extension BrowserWindowController: WKUIDelegate {
    /// Handles `window.open()` and `target="_blank"` links.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        switch Settings.shared.popupBehavior {
        case .block:
            return nil
        case .sameWindow:
            if navigationAction.request.url != nil {
                webView.load(navigationAction.request)
            }
            return nil
        case .newWindow:
            // Must use the configuration WebKit passes in so `window.opener` keeps working.
            let controller = AppDelegate.shared.openPopupWindow(configuration: configuration)
            if let width = windowFeatures.width?.doubleValue, let height = windowFeatures.height?.doubleValue,
               let popupWindow = controller.window {
                popupWindow.setContentSize(NSSize(width: max(width, 320), height: max(height, 320)))
            }
            return controller.webView
        }
    }

    func webViewDidClose(_ webView: WKWebView) {
        window?.close()
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = frame.request.url?.host ?? "This page says"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        showAlert(alert) { _ in completionHandler() }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = frame.request.url?.host ?? "This page says"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        showAlert(alert) { completionHandler($0 == .alertFirstButtonReturn) }
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = frame.request.url?.host ?? "This page says"
        alert.informativeText = prompt
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.stringValue = defaultText ?? ""
        alert.accessoryView = input
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = input
        showAlert(alert) { completionHandler($0 == .alertFirstButtonReturn ? input.stringValue : nil) }
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = true
        if let window = window {
            panel.beginSheetModal(for: window) { completionHandler($0 == .OK ? panel.urls : nil) }
        } else {
            completionHandler(panel.runModal() == .OK ? panel.urls : nil)
        }
    }

    @available(macOS 12.0, *)
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.prompt)
    }

    private func showAlert(_ alert: NSAlert, completion: @escaping (NSApplication.ModalResponse) -> Void) {
        if let window = window, window.isVisible {
            alert.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(alert.runModal())
        }
    }
}
