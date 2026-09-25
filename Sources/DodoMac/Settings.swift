import Foundation

enum PopupBehavior: String, CaseIterable {
    case newWindow
    case sameWindow
    case block

    var title: String {
        switch self {
        case .newWindow: return "Open in a new window"
        case .sameWindow: return "Open in the same window"
        case .block: return "Block"
        }
    }
}

extension Notification.Name {
    static let browserSettingsChanged = Notification.Name("BrowserSettingsChanged")
}

/// User preferences, persisted in UserDefaults.
final class Settings {
    static let shared = Settings()

    static let defaultHomeURL = "https://netmirror.app"

    private let defaults = UserDefaults.standard

    private enum Key {
        static let homeURL = "homeURL"
        static let profileID = "userAgentProfileID"
        static let customUserAgent = "customUserAgent"
        static let spoofNavigator = "spoofNavigator"
        static let popupBehavior = "popupBehavior"
        static let lastURL = "lastURL"
        static let restoreLastPage = "restoreLastPage"
        static let lastUserAgent = "lastUserAgent"
    }

    private init() {
        defaults.register(defaults: [
            Key.homeURL: Settings.defaultHomeURL,
            Key.profileID: UserAgentProfile.iPhoneWebView.id,
            Key.customUserAgent: "",
            Key.spoofNavigator: true,
            Key.popupBehavior: PopupBehavior.newWindow.rawValue,
            // Like Dodo, start from the home URL: the site decides where to send you from there.
            Key.restoreLastPage: false,
        ])
    }

    var homeURL: String {
        get { defaults.string(forKey: Key.homeURL) ?? Settings.defaultHomeURL }
        set { defaults.set(newValue, forKey: Key.homeURL) }
    }

    var profileID: String {
        get { defaults.string(forKey: Key.profileID) ?? UserAgentProfile.iPhoneWebView.id }
        set { defaults.set(newValue, forKey: Key.profileID) }
    }

    var customUserAgent: String {
        get { defaults.string(forKey: Key.customUserAgent) ?? "" }
        set { defaults.set(newValue, forKey: Key.customUserAgent) }
    }

    var spoofNavigator: Bool {
        get { defaults.bool(forKey: Key.spoofNavigator) }
        set { defaults.set(newValue, forKey: Key.spoofNavigator) }
    }

    var popupBehavior: PopupBehavior {
        get { PopupBehavior(rawValue: defaults.string(forKey: Key.popupBehavior) ?? "") ?? .newWindow }
        set { defaults.set(newValue.rawValue, forKey: Key.popupBehavior) }
    }

    var restoreLastPage: Bool {
        get { defaults.bool(forKey: Key.restoreLastPage) }
        set { defaults.set(newValue, forKey: Key.restoreLastPage) }
    }

    var lastURL: String? {
        get { defaults.string(forKey: Key.lastURL) }
        set { defaults.set(newValue, forKey: Key.lastURL) }
    }

    /// The User-Agent the website data was last used with.
    var lastUserAgent: String? {
        get { defaults.string(forKey: Key.lastUserAgent) }
        set { defaults.set(newValue, forKey: Key.lastUserAgent) }
    }

    var activeProfile: UserAgentProfile {
        if profileID == UserAgentProfile.customID {
            let ua = customUserAgent.trimmingCharacters(in: .whitespacesAndNewlines)
            return ua.isEmpty ? .iPhoneWebView : .custom(userAgent: ua)
        }
        return UserAgentProfile.presets.first { $0.id == profileID } ?? .iPhoneWebView
    }

    /// The page to open when a new main window is created.
    var startURL: URL? {
        if restoreLastPage, let last = lastURL, let url = URL(string: last) {
            return url
        }
        return URLNormalizer.url(from: homeURL)
    }

    func notifyChanged() {
        NotificationCenter.default.post(name: .browserSettingsChanged, object: nil)
    }
}

enum URLNormalizer {
    /// Turns address-bar input into a URL: adds https:// when missing and falls back to a search.
    static func url(from input: String) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if let url = URL(string: text), let scheme = url.scheme?.lowercased(),
           ["http", "https", "file", "about", "data", "blob"].contains(scheme) {
            return url
        }
        if !text.contains(" "), text.contains("."), let url = URL(string: "https://" + text) {
            return url
        }
        var components = URLComponents(string: "https://duckduckgo.com/")
        components?.queryItems = [URLQueryItem(name: "q", value: text)]
        return components?.url
    }
}
