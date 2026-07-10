import Cocoa

struct CommandResult {
    let exitCode: Int32
    let output: String
}

struct ClaudeStatus {
    let title: String
    let detail: String
    let isProxy: Bool

    static let unknown = ClaudeStatus(
        title: "Unknown",
        detail: "Status has not been loaded yet.",
        isProxy: false
    )
}

final class WrappingMenuItemView: NSView {
    private let width: CGFloat
    private let textWidth: CGFloat
    private let verticalPadding: CGFloat
    private let textField = NSTextField(labelWithString: "")
    private let font: NSFont

    init(width: CGFloat, font: NSFont, textColor: NSColor, verticalPadding: CGFloat = 6) {
        self.width = width
        self.textWidth = width - 24
        self.verticalPadding = verticalPadding
        self.font = font

        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 28))

        textField.font = font
        textField.textColor = textColor
        textField.lineBreakMode = .byWordWrapping
        textField.maximumNumberOfLines = 0
        textField.usesSingleLineMode = false
        textField.translatesAutoresizingMaskIntoConstraints = false

        addSubview(textField)

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            textField.topAnchor.constraint(equalTo: topAnchor, constant: verticalPadding),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -verticalPadding)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setText(_ text: String) {
        textField.stringValue = text

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributed = NSAttributedString(
            string: text.isEmpty ? " " : text,
            attributes: [
                .font: font,
                .paragraphStyle: paragraphStyle
            ]
        )

        let measured = attributed.boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let height = max(24, ceil(measured.height) + (verticalPadding * 2))

        frame = NSRect(x: frame.origin.x, y: frame.origin.y, width: width, height: height)
        invalidateIntrinsicContentSize()
    }
}

final class ClaudeToggleApp: NSObject, NSApplicationDelegate {
    private let menuWidth: CGFloat = 620
    private let statusItem = NSStatusBar.system.statusItem(withLength: 24)
    private let menu = NSMenu()
    private let statusMenuItem = NSMenuItem(title: "Loading status...", action: nil, keyEquivalent: "")
    private let detailMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let lastActionMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private lazy var statusView = WrappingMenuItemView(
        width: menuWidth,
        font: .systemFont(ofSize: NSFont.systemFontSize, weight: .medium),
        textColor: .labelColor
    )
    private lazy var detailView = WrappingMenuItemView(
        width: menuWidth,
        font: .systemFont(ofSize: NSFont.systemFontSize),
        textColor: .secondaryLabelColor
    )

    private var currentStatus = ClaudeStatus.unknown
    private var isRunningCommand = false
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusButton()
        configureMenu()
        refreshStatus()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refreshStatus()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
    }

    @objc private func refreshStatusAction(_ sender: Any?) {
        refreshStatus(force: true)
    }

    @objc private func useLogin(_ sender: Any?) {
        runSwitch(scriptName: "login-claude.sh", actionName: "Switching to login credentials")
    }

    @objc private func useCLIProxy(_ sender: Any?) {
        runSwitch(scriptName: "cliproxy-claude.sh", actionName: "Switching to CLIProxyAPI")
    }

    @objc private func useAPIKeyFun(_ sender: Any?) {
        runSwitch(scriptName: "apikeyfun-claude.sh", actionName: "Switching to apikey.fun pool")
    }

    @objc private func useAntigravity(_ sender: Any?) {
        runSwitch(scriptName: "antigravity-claude.sh", actionName: "Switching to Antigravity pool")
    }

    @objc private func openClaudeSettings(_ sender: Any?) {
        let settingsURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".claude/settings.json")
        NSWorkspace.shared.open(settingsURL)
    }

    @objc private func openScriptsFolder(_ sender: Any?) {
        NSWorkspace.shared.open(scriptRoot())
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.title = ""
        button.image = makeMenuBarIcon()
        button.imagePosition = .imageOnly
        button.toolTip = "Claude Code toggle"
    }

    private func configureMenu() {
        statusMenuItem.isEnabled = false
        detailMenuItem.isEnabled = false
        lastActionMenuItem.isEnabled = false
        statusMenuItem.view = statusView
        detailMenuItem.view = detailView

        menu.addItem(statusMenuItem)
        menu.addItem(detailMenuItem)
        menu.addItem(lastActionMenuItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Use Login Credentials", action: #selector(useLogin(_:)), keyEquivalent: "l"))
        menu.addItem(NSMenuItem(title: "Use CLIProxyAPI", action: #selector(useCLIProxy(_:)), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "Use apikey.fun Pool", action: #selector(useAPIKeyFun(_:)), keyEquivalent: "a"))
        menu.addItem(NSMenuItem(title: "Use Antigravity Pool", action: #selector(useAntigravity(_:)), keyEquivalent: "g"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Refresh Status", action: #selector(refreshStatusAction(_:)), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Open Claude Settings", action: #selector(openClaudeSettings(_:)), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Open Scripts Folder", action: #selector(openScriptsFolder(_:)), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Claude Toggle", action: #selector(quit(_:)), keyEquivalent: "q"))

        for item in menu.items where item.action != nil {
            item.target = self
        }

        statusItem.menu = menu
    }

    private func refreshStatus(force: Bool = false) {
        if isRunningCommand && !force {
            return
        }

        runCommand(scriptName: "status-claude.sh") { [weak self] result in
            guard let self else { return }

            if result.exitCode == 0 {
                self.currentStatus = self.parseStatus(result.output)
                self.lastActionMenuItem.title = ""
            } else {
                self.currentStatus = ClaudeStatus(
                    title: "Error",
                    detail: trimmed(result.output).nonEmpty ?? "Unable to read status.",
                    isProxy: false
                )
            }

            self.renderStatus()
        }
    }

    private func runSwitch(scriptName: String, actionName: String) {
        guard !isRunningCommand else { return }

        isRunningCommand = true
        setMenuItemsEnabled(false)
        statusItem.button?.toolTip = "Claude Code: switching..."
        lastActionMenuItem.title = actionName + "..."

        runCommand(scriptName: scriptName) { [weak self] result in
            guard let self else { return }

            self.isRunningCommand = false
            self.setMenuItemsEnabled(true)

            if result.exitCode == 0 {
                self.lastActionMenuItem.title = "Last action: " + actionName.replacingOccurrences(of: "Switching", with: "Switched")
                self.refreshStatus(force: true)
            } else {
                self.lastActionMenuItem.title = "Last action failed"
                self.renderStatus()
                self.showError(title: "Claude Toggle Failed", output: result.output)
            }
        }
    }

    private func setMenuItemsEnabled(_ enabled: Bool) {
        for item in menu.items where item.action != nil && item.action != #selector(quit(_:)) {
            item.isEnabled = enabled
        }
    }

    private func renderStatus() {
        statusItem.button?.toolTip = "Claude Code: " + currentStatus.title
        statusView.setText("Mode: " + currentStatus.title)
        detailView.setText(currentStatus.detail)
    }

    private func makeMenuBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()

        NSColor.black.setStroke()
        NSColor.black.setFill()

        let delta = NSBezierPath()
        delta.move(to: NSPoint(x: 9, y: 16.2))
        delta.curve(to: NSPoint(x: 3.4, y: 2.3), controlPoint1: NSPoint(x: 6.6, y: 11.2), controlPoint2: NSPoint(x: 4.8, y: 6.7))
        delta.curve(to: NSPoint(x: 9, y: 5.4), controlPoint1: NSPoint(x: 5.2, y: 3.4), controlPoint2: NSPoint(x: 7.1, y: 4.4))
        delta.curve(to: NSPoint(x: 14.6, y: 2.3), controlPoint1: NSPoint(x: 10.9, y: 4.4), controlPoint2: NSPoint(x: 12.8, y: 3.4))
        delta.curve(to: NSPoint(x: 9, y: 16.2), controlPoint1: NSPoint(x: 13.2, y: 6.7), controlPoint2: NSPoint(x: 11.4, y: 11.2))
        delta.close()
        delta.lineWidth = 1.4
        delta.stroke()

        let center = NSPoint(x: 9, y: 8.2)
        let claudeRays: [(CGFloat, CGFloat)] = [
            (-90, 2.1), (-45, 2.7), (0, 2.9), (45, 2.7),
            (90, 2.1), (135, 2.4), (180, 2.6), (225, 2.4)
        ]

        for (degrees, length) in claudeRays {
            let radians = degrees * .pi / 180
            let inner = NSPoint(
                x: center.x + cos(radians) * 1.4,
                y: center.y + sin(radians) * 1.4
            )
            let outer = NSPoint(
                x: center.x + cos(radians) * length,
                y: center.y + sin(radians) * length
            )

            let ray = NSBezierPath()
            ray.move(to: inner)
            ray.line(to: outer)
            ray.lineWidth = 1.2
            ray.lineCapStyle = .round
            ray.stroke()
        }

        NSBezierPath(ovalIn: NSRect(x: center.x - 1.15, y: center.y - 1.15, width: 2.3, height: 2.3)).fill()

        image.unlockFocus()
        image.isTemplate = true
        image.accessibilityDescription = "Claude Toggle"
        return image
    }

    private func parseStatus(_ output: String) -> ClaudeStatus {
        let lines = output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)

        let modeLine = lines.first { $0.hasPrefix("Mode:") } ?? "Mode: Unknown"
        let baseMode = modeLine.replacingOccurrences(of: "Mode:", with: "").trimmingCharacters(in: .whitespaces)

        if baseMode == "login credentials" {
            return ClaudeStatus(title: "Login", detail: "Using normal Claude Code login credentials", isProxy: false)
        }

        let modelLines = lines.filter { $0.hasPrefix("ANTHROPIC_DEFAULT_") }
        let detail = modelLines.isEmpty
            ? lines.dropFirst().joined(separator: " | ")
            : modelLines.joined(separator: "\n")

        let inferredTitle: String
        if output.contains("claude-sonnet-4-5-20250929") {
            inferredTitle = "apikey.fun"
        } else if output.contains("claude-opus-4-6-thinking") || output.contains("gemini-3.1-flash-lite") {
            inferredTitle = "Antigravity"
        } else if baseMode == "CLIProxyAPI" {
            inferredTitle = "CLIProxyAPI"
        } else {
            inferredTitle = baseMode
        }

        return ClaudeStatus(
            title: inferredTitle,
            detail: trimmed(detail).nonEmpty ?? "CLIProxyAPI settings are configured",
            isProxy: true
        )
    }

    private func runCommand(scriptName: String, completion: @escaping (CommandResult) -> Void) {
        let scriptURL = scriptRoot().appendingPathComponent(scriptName)

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptURL.path]
            process.currentDirectoryURL = self.scriptRoot()
            process.standardOutput = pipe
            process.standardError = pipe
            process.environment = self.commandEnvironment()

            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                DispatchQueue.main.async {
                    completion(CommandResult(exitCode: process.terminationStatus, output: output))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(CommandResult(exitCode: 1, output: error.localizedDescription))
                }
            }
        }
    }

    private func scriptRoot() -> URL {
        if let configured = ProcessInfo.processInfo.environment["CLAUDE_TOGGLE_DIR"], !configured.isEmpty {
            return URL(fileURLWithPath: configured)
        }

        if let resourceScripts = Bundle.main.resourceURL?.appendingPathComponent("Scripts"),
           FileManager.default.fileExists(atPath: resourceScripts.appendingPathComponent("status-claude.sh").path) {
            return resourceScripts
        }

        let bundleParent = Bundle.main.bundleURL.deletingLastPathComponent()
        let repoRoot = bundleParent.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("status-claude.sh").path) {
            return repoRoot
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    private func commandEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["HOME"] = NSHomeDirectory()
        env["PATH"] = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ].joined(separator: ":")
        env["LC_ALL"] = "en_US.UTF-8"
        return env
    }

    private func showError(title: String, output: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = trimmed(output).prefixString(maxLength: 1200)
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

private func trimmed(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }

    func prefixString(maxLength: Int) -> String {
        if count <= maxLength {
            return self
        }

        let end = index(startIndex, offsetBy: maxLength)
        return String(self[..<end]) + "\n..."
    }
}

let app = NSApplication.shared
let delegate = ClaudeToggleApp()
app.delegate = delegate
app.run()
