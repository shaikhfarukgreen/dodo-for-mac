import WebKit

/// Blocks ads with a WebKit content rule list:
/// - requests to well-known ad / pop-under / push-ad networks (always, when ad blocking is on);
/// - optionally ("strict"), every third-party script except an allowlist of common libraries,
///   which catches ad scripts from networks not on the list.
enum AdBlocker {
    private static let identifier = "DodoAdBlock-v1"
    private static let strictIdentifier = "DodoAdBlockStrict-v1"

    private(set) static var networkRules: WKContentRuleList?
    private(set) static var strictRules: WKContentRuleList?

    static let adDomains = [
        "doubleclick.net", "googlesyndication.com", "googleadservices.com", "adservice.google.com",
        "google-analytics.com", "googletagmanager.com", "googletagservices.com", "amazon-adsystem.com",
        "adnxs.com", "taboola.com", "outbrain.com", "criteo.com", "criteo.net", "pubmatic.com",
        "rubiconproject.com", "openx.net", "adform.net", "smartadserver.com", "yieldmo.com",
        "popads.net", "popcash.net", "propellerads.com", "propellerclick.com", "adsterra.com",
        "adsterratech.com", "exoclick.com", "exosrv.com", "juicyads.com", "trafficjunky.net",
        "trafficstars.com", "tsyndicate.com", "hilltopads.net", "hilltopads.com", "adcash.com",
        "clickadu.com", "clickaine.com", "monetag.com", "a-ads.com", "adspyglass.com", "onclickads.net",
        "onclkds.com", "onclickalgo.com", "popmyads.com", "richpush.co", "pushground.com",
        "rollerads.com", "evadav.com", "galaksion.com", "admaven.com", "ad-maven.com", "admaven.net",
        "mgid.com", "revcontent.com", "bidvertiser.com", "adskeeper.com", "adskeeper.co.uk",
        "adsco.re", "yllix.com", "coinzilla.com", "bitmedia.io", "adf.ly", "shorte.st",
        "ero-advertising.com", "plugrush.com", "clickaine.com", "zeydoo.com", "dolohen.com",
        "highperformanceformat.com", "profitablecpmrate.com", "profitablegatecpm.com",
        "effectiveratecpm.com", "effectivegatecpm.com", "displaycontentnetwork.com",
        "whos.amung.us", "histats.com",
    ]

    /// Third-party script hosts that are allowed even in strict mode (security checks, common libraries, players).
    static let allowedScriptDomains = [
        "cloudflare.com", "cloudflareinsights.com", "jquery.com", "jsdelivr.net", "unpkg.com",
        "gstatic.com", "google.com", "recaptcha.net", "googleapis.com", "bootstrapcdn.com",
        "jwpcdn.com", "jwplayer.com", "zencdn.net", "plyr.io", "hlsjs.video-dev.org", "fontawesome.com",
    ]

    /// Anchored "this host or any subdomain" filter in WebKit content-blocker regex syntax.
    private static func hostFilter(_ domain: String) -> String {
        "^[^:]+://+([^:/]+\\\\.)?" + domain.replacingOccurrences(of: ".", with: "\\\\.") + "[:/]"
    }

    private static var networkRulesJSON: String {
        let rules = adDomains.map { domain in
            #"{"trigger":{"url-filter":"\#(hostFilter(domain))"},"action":{"type":"block"}}"#
        }
        return "[" + rules.joined(separator: ",") + "]"
    }

    private static var strictRulesJSON: String {
        var rules = [#"{"trigger":{"url-filter":".*","resource-type":["script"],"load-type":["third-party"]},"action":{"type":"block"}}"#]
        // Later rules win: re-allow the listed hosts.
        rules += allowedScriptDomains.map { domain in
            #"{"trigger":{"url-filter":"\#(hostFilter(domain))","resource-type":["script"]},"action":{"type":"ignore-previous-rules"}}"#
        }
        return "[" + rules.joined(separator: ",") + "]"
    }

    /// Compiles both rule lists (cached by WebKit on disk), then calls `completion` on the main thread.
    static func prepare(completion: @escaping () -> Void) {
        guard let store = WKContentRuleListStore.default() else {
            completion()
            return
        }
        let group = DispatchGroup()
        group.enter()
        store.compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: networkRulesJSON) { list, error in
            if let error = error { NSLog("Ad block rules failed to compile: \(error)") }
            networkRules = list
            group.leave()
        }
        group.enter()
        store.compileContentRuleList(forIdentifier: strictIdentifier, encodedContentRuleList: strictRulesJSON) { list, error in
            if let error = error { NSLog("Strict ad block rules failed to compile: \(error)") }
            strictRules = list
            group.leave()
        }
        group.notify(queue: .main, execute: completion)
    }

    /// Adds or removes the rule lists on a configuration to match the current settings.
    static func apply(to controller: WKUserContentController) {
        controller.removeAllContentRuleLists()
        let settings = Settings.shared
        guard settings.blockAds else { return }
        if let list = networkRules {
            controller.add(list)
        }
        if settings.strictScriptBlocking, let list = strictRules {
            controller.add(list)
        }
    }

    /// True when `url` belongs to a known ad network (used to stop ad redirects and pop-ups).
    static func isAdURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return adDomains.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    /// Rough "same site" check: compares the last two labels of the host (net77.cc, netmirror.gg).
    static func siteKey(_ url: URL?) -> String? {
        guard let host = url?.host?.lowercased() else { return nil }
        return host.split(separator: ".").suffix(2).joined(separator: ".")
    }
}
