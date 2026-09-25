import AppKit

final class SettingsWindowController: NSWindowController {
    private let homeField = NSTextField()
    private let profilePopup = NSPopUpButton()
    private let customUAField = NSTextField()
    private let spoofCheckbox = NSButton(checkboxWithTitle: "Make navigator.platform / touch support match the device", target: nil, action: nil)
    private let restoreCheckbox = NSButton(checkboxWithTitle: "Reopen the last page on launch", target: nil, action: nil)
    private let popupBehaviorPopup = NSPopUpButton()

    private var profileIDs: [String] = []

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
        loadValues()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func buildUI() {
        for profile in UserAgentProfile.presets {
            profilePopup.addItem(withTitle: profile.name)
            profileIDs.append(profile.id)
        }
        profilePopup.addItem(withTitle: "Custom User-Agent…")
        profileIDs.append(UserAgentProfile.customID)
        profilePopup.target = self
        profilePopup.action = #selector(profileChanged(_:))

        for behavior in PopupBehavior.allCases {
            popupBehaviorPopup.addItem(withTitle: behavior.title)
        }

        homeField.placeholderString = Settings.defaultHomeURL
        customUAField.placeholderString = "Paste the exact User-Agent from Dodo on your iPhone"
        customUAField.lineBreakMode = .byTruncatingTail
        customUAField.cell?.isScrollable = true
        customUAField.usesSingleLineMode = true

        let hint = NSTextField(wrappingLabelWithString: "Tip: to copy Dodo’s exact identity, open a “what is my user agent” page in Dodo on your iPhone and paste the result into Custom User-Agent.")
        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hint.textColor = .secondaryLabelColor

        let grid = NSGridView(views: [
            [label("Home page:"), homeField],
            [label("Identify as:"), profilePopup],
            [label("Custom User-Agent:"), customUAField],
            [NSGridCell.emptyContentView, spoofCheckbox],
            [label("Pop-up windows:"), popupBehaviorPopup],
            [NSGridCell.emptyContentView, restoreCheckbox],
            [NSGridCell.emptyContentView, hint],
        ])
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        grid.rowSpacing = 10
        grid.columnSpacing = 8
        grid.translatesAutoresizingMaskIntoConstraints = false

        let resetButton = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetDefaults(_:)))
        let saveButton = NSButton(title: "Save", target: self, action: #selector(save(_:)))
        saveButton.keyEquivalent = "\r"
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel(_:)))
        cancelButton.keyEquivalent = "\u{1b}"

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.addView(resetButton, in: .leading)
        buttons.addView(cancelButton, in: .trailing)
        buttons.addView(saveButton, in: .trailing)
        buttons.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(grid)
        content.addSubview(buttons)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            homeField.widthAnchor.constraint(greaterThanOrEqualToConstant: 420),
            customUAField.widthAnchor.constraint(equalTo: homeField.widthAnchor),
            hint.widthAnchor.constraint(equalTo: homeField.widthAnchor),
            buttons.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 20),
            buttons.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
        ])
        window?.contentView = content
    }

    private func label(_ text: String) -> NSTextField {
        NSTextField(labelWithString: text)
    }

    private func loadValues() {
        let settings = Settings.shared
        homeField.stringValue = settings.homeURL
        profilePopup.selectItem(at: profileIDs.firstIndex(of: settings.profileID) ?? 0)
        customUAField.stringValue = settings.customUserAgent
        spoofCheckbox.state = settings.spoofNavigator ? .on : .off
        restoreCheckbox.state = settings.restoreLastPage ? .on : .off
        popupBehaviorPopup.selectItem(at: PopupBehavior.allCases.firstIndex(of: settings.popupBehavior) ?? 0)
        updateCustomFieldState()
    }

    private func updateCustomFieldState() {
        let isCustom = profileIDs[profilePopup.indexOfSelectedItem] == UserAgentProfile.customID
        customUAField.isEnabled = isCustom
        if !isCustom {
            customUAField.stringValue = UserAgentProfile.presets[profilePopup.indexOfSelectedItem].userAgent
        } else if customUAField.stringValue.isEmpty
                    || UserAgentProfile.presets.contains(where: { $0.userAgent == customUAField.stringValue }) {
            customUAField.stringValue = Settings.shared.customUserAgent
        }
    }

    func reload() {
        loadValues()
    }

    @objc private func profileChanged(_ sender: Any?) {
        updateCustomFieldState()
    }

    @objc private func resetDefaults(_ sender: Any?) {
        homeField.stringValue = Settings.defaultHomeURL
        profilePopup.selectItem(at: 0)
        spoofCheckbox.state = .on
        restoreCheckbox.state = .on
        popupBehaviorPopup.selectItem(at: 0)
        updateCustomFieldState()
    }

    @objc private func save(_ sender: Any?) {
        let settings = Settings.shared
        let home = homeField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.homeURL = home.isEmpty ? Settings.defaultHomeURL : home
        settings.profileID = profileIDs[profilePopup.indexOfSelectedItem]
        if settings.profileID == UserAgentProfile.customID {
            settings.customUserAgent = customUAField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        settings.spoofNavigator = spoofCheckbox.state == .on
        settings.restoreLastPage = restoreCheckbox.state == .on
        settings.popupBehavior = PopupBehavior.allCases[popupBehaviorPopup.indexOfSelectedItem]
        settings.notifyChanged()
        window?.close()
    }

    @objc private func cancel(_ sender: Any?) {
        window?.close()
    }
}
