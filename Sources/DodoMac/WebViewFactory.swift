import WebKit

/// Builds WKWebView configurations that behave like an iOS in-app browser (e.g. Dodo).
enum WebViewFactory {
    /// Shared so cookies, logins and local storage are the same in every window and survive restarts.
    static let processPool = WKProcessPool()
    static let dataStore = WKWebsiteDataStore.default()

    static func makeConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.processPool = processPool
        config.websiteDataStore = dataStore
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true
        config.suppressesIncrementalRendering = false

        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.preferences.isFraudulentWebsiteWarningEnabled = false
        if #available(macOS 12.3, *) {
            config.preferences.isElementFullscreenEnabled = true
        }
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        applyProfile(to: config)
        return config
    }

    /// Installs the per-profile settings (content mode + navigator spoofing script).
    static func applyProfile(to config: WKWebViewConfiguration) {
        let settings = Settings.shared
        let profile = settings.activeProfile

        config.defaultWebpagePreferences.preferredContentMode = profile.prefersMobileContent ? .mobile : .desktop

        let controller = config.userContentController
        controller.removeAllUserScripts()
        if settings.spoofNavigator, let source = profile.spoofingScript {
            let script = WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            controller.addUserScript(script)
        }
    }

    static func makeWebView(configuration: WKWebViewConfiguration) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = Settings.shared.activeProfile.userAgent
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
        return webView
    }
}
