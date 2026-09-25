import Foundation

/// A device identity the browser can present to websites.
///
/// `userAgent` is sent in the HTTP `User-Agent` header and returned by `navigator.userAgent`.
/// `platform` / `maxTouchPoints` are injected into JavaScript so that sites which also check
/// `navigator.platform` or touch support see a consistent iOS device.
struct UserAgentProfile: Equatable {
    let id: String
    let name: String
    let userAgent: String
    let platform: String?
    let maxTouchPoints: Int
    let prefersMobileContent: Bool

    static let iPhoneWebView = UserAgentProfile(
        id: "iphone-webview",
        name: "iPhone – in-app WebView (Dodo-style)",
        userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
        platform: "iPhone",
        maxTouchPoints: 5,
        prefersMobileContent: true
    )

    static let iPhoneSafari = UserAgentProfile(
        id: "iphone-safari",
        name: "iPhone – Safari",
        userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Mobile/15E148 Safari/604.1",
        platform: "iPhone",
        maxTouchPoints: 5,
        prefersMobileContent: true
    )

    static let iPad = UserAgentProfile(
        id: "ipad-safari",
        name: "iPad – Safari",
        userAgent: "Mozilla/5.0 (iPad; CPU OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Mobile/15E148 Safari/604.1",
        platform: "iPad",
        maxTouchPoints: 5,
        prefersMobileContent: true
    )

    static let macSafari = UserAgentProfile(
        id: "mac-safari",
        name: "Mac – Safari (no spoofing)",
        userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Safari/605.1.15",
        platform: nil,
        maxTouchPoints: 0,
        prefersMobileContent: false
    )

    static let customID = "custom"

    static let presets: [UserAgentProfile] = [iPhoneWebView, iPhoneSafari, iPad, macSafari]

    static func custom(userAgent: String) -> UserAgentProfile {
        let lower = userAgent.lowercased()
        let platform: String?
        if lower.contains("iphone") {
            platform = "iPhone"
        } else if lower.contains("ipad") {
            platform = "iPad"
        } else if lower.contains("android") {
            platform = "Linux armv8l"
        } else {
            platform = nil
        }
        return UserAgentProfile(
            id: customID,
            name: "Custom",
            userAgent: userAgent,
            platform: platform,
            maxTouchPoints: platform == nil ? 0 : 5,
            prefersMobileContent: platform != nil
        )
    }

    /// JavaScript injected at document start in every frame so `navigator` matches the User-Agent.
    var spoofingScript: String? {
        guard let platform = platform else { return nil }
        let escapedPlatform = platform.replacingOccurrences(of: "'", with: "\\'")
        return """
        (function () {
          var define = function (obj, key, value) {
            try { Object.defineProperty(obj, key, { get: function () { return value; }, configurable: true }); } catch (e) {}
          };
          define(Navigator.prototype, 'platform', '\(escapedPlatform)');
          define(Navigator.prototype, 'maxTouchPoints', \(maxTouchPoints));
          define(Navigator.prototype, 'vendor', 'Apple Computer, Inc.');
          define(Navigator.prototype, 'standalone', false);
          if (!('ontouchstart' in window)) { window.ontouchstart = null; }
          if (!('ontouchstart' in document.documentElement)) { document.documentElement.ontouchstart = null; }
          if (typeof window.orientation === 'undefined') { define(window, 'orientation', 0); }
        })();
        """
    }
}
