import AppKit
import WebKit

/// Records what a site does while loading (redirects, status codes, what page scripts read from
/// `navigator`/`screen`, inline script source) so detection logic can be found without dev tools.
/// Off by default: the probe wraps browser getters, which some bot checks could notice.
final class Diagnostics: NSObject, WKScriptMessageHandler {
    static let shared = Diagnostics()
    static let handlerName = "dodoDiag"

    private(set) var isRecording = false
    private var lines: [String] = []
    private let maxLines = 5000
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    func setRecording(_ recording: Bool) {
        isRecording = recording
        if recording {
            lines.removeAll()
            log("=== Recording started. User-Agent: \(Settings.shared.activeProfile.userAgent)")
            log("=== Spoof navigator: \(Settings.shared.spoofNavigator)")
        }
    }

    func log(_ message: String) {
        guard isRecording else { return }
        lines.append("\(timeFormatter.string(from: Date()))  \(message)")
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        log("JS  \(message.body)")
    }

    /// Captures the loaded page's inline scripts and external script URLs. Cookie values are never recorded.
    func snapshot(_ webView: WKWebView) {
        guard isRecording else { return }
        let js = """
        (function () {
          var out = [];
          out.push('title: ' + document.title);
          out.push('cookie names: ' + document.cookie.split(';').map(function (c) { return c.split('=')[0].trim(); }).filter(Boolean).join(', '));
          document.querySelectorAll('meta[http-equiv]').forEach(function (m) { out.push('meta ' + m.httpEquiv + ': ' + m.content); });
          document.querySelectorAll('script[src]').forEach(function (s) { out.push('script src: ' + s.src); });
          var inline = Array.prototype.filter.call(document.querySelectorAll('script:not([src])'), function (s) { return s.textContent.trim().length > 0; });
          inline.slice(0, 15).forEach(function (s, i) { out.push('--- inline script ' + (i + 1) + ' (' + s.textContent.length + ' chars) ---\\n' + s.textContent.slice(0, 6000)); });
          return out.join('\\n');
        })();
        """
        let url = webView.url?.absoluteString ?? "?"
        webView.evaluateJavaScript(js) { [weak self] result, error in
            if let text = result as? String {
                self?.log("PAGE \(url)\n\(text)\n--- end of page \(url) ---")
            } else if let error = error {
                self?.log("PAGE \(url) snapshot failed: \(error.localizedDescription)")
            }
        }
    }

    func saveReport() {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let url = desktop.appendingPathComponent("DodoMac-diagnostics.txt")
        let text = lines.isEmpty ? "Nothing recorded. Turn on Help > Record Diagnostics, then load the site." : lines.joined(separator: "\n")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    /// Reports which fingerprinting properties page scripts read. Runs after the spoofing script.
    static let probeScript = """
    (function () {
      var handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.dodoDiag;
      if (!handler) { return; }
      var where = location.host + location.pathname + (window === window.top ? '' : ' [frame]');
      var seen = {};
      var report = function (what) {
        if (seen[what]) { return; }
        seen[what] = true;
        try { handler.postMessage(where + ' reads ' + what); } catch (e) {}
      };
      var wrap = function (proto, name, label) {
        var d = Object.getOwnPropertyDescriptor(proto, name);
        if (!d || !d.get || !d.configurable) { return; }
        Object.defineProperty(proto, name, { get: function () { report(label); return d.get.call(this); }, configurable: true });
      };
      ['userAgent', 'platform', 'maxTouchPoints', 'vendor', 'webdriver', 'languages', 'language', 'hardwareConcurrency',
       'deviceMemory', 'standalone', 'userAgentData', 'plugins', 'mimeTypes', 'connection', 'cookieEnabled'].forEach(function (n) {
        wrap(Navigator.prototype, n, 'navigator.' + n);
      });
      ['width', 'height', 'availWidth', 'availHeight', 'colorDepth', 'pixelDepth'].forEach(function (n) {
        wrap(Screen.prototype, n, 'screen.' + n);
      });
      var matchMedia = window.matchMedia;
      if (matchMedia) {
        window.matchMedia = function (q) { report('matchMedia(' + q + ')'); return matchMedia.apply(this, arguments); };
      }
      if (window.WebGLRenderingContext) {
        var getParameter = WebGLRenderingContext.prototype.getParameter;
        WebGLRenderingContext.prototype.getParameter = function (p) { report('webgl.getParameter(' + p + ')'); return getParameter.apply(this, arguments); };
      }
      window.addEventListener('error', function (e) { try { handler.postMessage(where + ' JS error: ' + e.message); } catch (x) {} });
    })();
    """
}
