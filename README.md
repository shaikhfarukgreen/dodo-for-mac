# Dodo for Mac

A small native macOS browser that behaves like the **Dodo** in-app browser on iOS, so
sites that only work in Dodo (for example `https://netmirror.app`) also open on a Mac.

It uses Apple's **WKWebView** (the same WebKit engine Dodo uses on iPhone) and presents
itself to websites as an iPhone:

| What the site checks | What Dodo for Mac sends |
| --- | --- |
| `User-Agent` HTTP header | iOS WebView User-Agent (configurable, or paste Dodo's exact one) |
| `navigator.userAgent` | same as above |
| `navigator.platform`, `maxTouchPoints`, `ontouchstart` | iPhone values (injected at document start in every frame) |
| Layout / viewport | WebKit "mobile" content mode |

Other features:

- Opens `https://netmirror.app` by default and restores the last page on launch
- Cookies / logins are kept between launches and shared across windows
- Video autoplay, HLS playback, AirPlay and HTML5 full-screen video
- `window.open` / `target=_blank` popups (new window, same window, or blocked; see Settings)
- JavaScript `alert` / `confirm` / `prompt`, file uploads, downloads to `~/Downloads`
- Address bar, back/forward, reload, zoom, ⌘-click to open in a new window
- Web Inspector enabled (right-click → Inspect Element) for debugging

## Download a prebuilt app

Each push runs the **Build macOS app** GitHub Action. Open the latest run under the
repository's *Actions* tab, download the `DodoForMac` artifact, unzip it and move
`Dodo for Mac.app` to `/Applications`.

The app is ad-hoc signed (not notarized), so on first launch **right-click → Open** or run:

```bash
xattr -dr com.apple.quarantine "/Applications/Dodo for Mac.app"
```

## Build it yourself

Requirements: macOS 12 or later and Xcode (or the Xcode Command Line Tools) with Swift 5.7 or later.

```bash
git clone https://github.com/shaikhfarukgreen/dodo-for-mac.git
cd dodo-for-mac
./scripts/build-app.sh          # builds build/Dodo for Mac.app (Apple Silicon + Intel)
open "build/Dodo for Mac.app"
```

If your toolchain can't build universal binaries, use `SINGLE_ARCH=1 ./scripts/build-app.sh`.

To work on it in Xcode, open `Package.swift`. You can also run it directly with `swift run`.

## If the site still refuses to load

Sites sometimes check the exact Dodo User-Agent string. To copy it:

1. On your iPhone, open Dodo and visit a "what is my user agent" page (for example `whatmyuseragent.com`).
2. Copy the full string it shows.
3. On the Mac, open **Dodo for Mac → Settings… (⌘,)** and choose **Identify as: Custom User-Agent…**.
4. Paste the string, click **Save**. All windows reload with the new identity.

**Dodo for Mac → Clear Website Data…** resets cookies and cache if a site is stuck in a bad state.

## Project layout

```
Package.swift                         Swift package (macOS 12+)
Resources/Info.plist                  App bundle metadata
scripts/build-app.sh                  Builds and ad-hoc signs the .app bundle
Sources/DodoMac/
  main.swift                          App entry point
  AppDelegate.swift                   Window management, app-level actions
  MainMenu.swift                      Menu bar and keyboard shortcuts
  BrowserWindowController.swift       Browser window, toolbar, WebKit delegates
  WebViewFactory.swift                WKWebView configuration (iOS-like behaviour)
  UserAgentProfile.swift              Device identities + navigator spoofing script
  Settings.swift                      Persisted preferences, address-bar parsing
  SettingsWindowController.swift      Settings window
  DownloadManager.swift               File downloads
```
