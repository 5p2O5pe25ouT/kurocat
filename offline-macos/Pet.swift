import AppKit
import WebKit

private struct MouseSample: Equatable {
    let point = NSEvent.mouseLocation
    let buttons = NSEvent.pressedMouseButtons & 7
    let left = CGEventSource.counterForEventType(.combinedSessionState, eventType: .leftMouseDown)
    let right = CGEventSource.counterForEventType(.combinedSessionState, eventType: .rightMouseDown)
    let wheel = CGEventSource.counterForEventType(.combinedSessionState, eventType: .scrollWheel)
}

final class Pet: NSObject, NSApplicationDelegate, WKNavigationDelegate, NSWindowDelegate {
    let web: WKWebView = {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        return WKWebView(frame: .zero, configuration: config)
    }()
    private let window = PetPanel()
    private let sizeLabel = NSTextField(labelWithString: "")
    private var hitTestPending = false
    private var nextHitTest: TimeInterval = 0
    private let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let defaults = UserDefaults.standard
    private var skins: [[String: String]] = []
    private var timer: Timer?
    private var previousMouse = MouseSample()
    private var previousCount: UInt32 = 0
    private var typingWindow: NSWindow?
    private let typingPad = TypingPad()
    private var displayingKeys = false
    private var ready = false
    private var reloadedAfterCrash = false
    private var skin: String { defaults.string(forKey: "skin") ?? "black" }
    private var use3D: Bool { defaults.bool(forKey: "use3D") }
    private let page = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "web")!

    func applicationDidFinishLaunching(_ notification: Notification) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        web.setValue(false, forKey: "drawsBackground")
        web.navigationDelegate = self
        window.contentView = web
        window.restorePlacement()
        status.button?.title = "🐈‍⬛"
        status.button?.toolTip = "KuroCat Offline"
        rebuildMenu()
        // WebKit requires the sandbox client entitlement even for file-only rendering.
        // Install the blocking rule before loading anything, including the startup page.
        let rules = #"""
        [
          {"trigger":{"url-filter":"^https?://"},"action":{"type":"block"}},
          {"trigger":{"url-filter":"^wss?://"},"action":{"type":"block"}},
          {"trigger":{"url-filter":"^ftp://"},"action":{"type":"block"}}
        ]
        """#
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "KuroCatOffline", encodedContentRuleList: rules) { [weak self] list, _ in
            guard let self, let list else { return }
            self.web.configuration.userContentController.add(list)
            self.loadPage()
        }
        window.orderFrontRegardless()
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let target = action.request.url?.standardizedFileURL
        decisionHandler(action.targetFrame?.isMainFrame == true && target == page.standardizedFileURL ? .allow : .cancel)
    }

    private func loadPage() {
        web.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        ready = false
        timer?.invalidate()
        if !reloadedAfterCrash {
            reloadedAfterCrash = true
            loadPage()
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        web.evaluateJavaScript("pet.skins") { [weak self] result, _ in
            guard let self, let options = result as? [[String: String]], !options.isEmpty else { return }
            self.skins = options
            self.applyAppearance()
            self.rebuildMenu()
        }
    }

    private func applyAppearance() {
        ready = false
        web.callAsyncJavaScript("pet.appearance(id, model)", arguments: ["id": skin, "model": use3D],
                                in: nil, in: .page) { [weak self] result in
            guard let self, case .success = result else { return }
            self.ready = true
            self.setKeyDisplay(self.typingPad.canShowKeys, force: true)
            self.previousCount = self.count()
            self.previousMouse = MouseSample()
            if self.timer?.isValid != true {
                let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.poll() }
                timer.tolerance = 0.008
                RunLoop.main.add(timer, forMode: .common)
                self.timer = timer
            }
        }
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        window.restorePlacement()
    }

    private func refreshDragRegion(at point: NSPoint, buttons: Int) {
        guard !window.isDraggingPet else { return }
        let frame = window.frame
        guard frame.contains(point) else {
            window.ignoresMouseEvents = true
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        guard buttons == 0, !hitTestPending,
              point != previousMouse.point || now >= nextHitTest else { return }
        hitTestPending = true
        nextHitTest = now + 0.20
        let args: [String: Any] = ["x": (point.x - frame.minX) / frame.width,
                                   "y": (frame.maxY - point.y) / frame.height]
        web.callAsyncJavaScript("return pet.hit(x, y)", arguments: args, in: nil, in: .page) { [weak self] result in
            guard let self else { return }
            self.hitTestPending = false
            guard !self.window.isDraggingPet, NSEvent.pressedMouseButtons == 0 else { return }
            let cursor = NSEvent.mouseLocation
            guard self.window.frame == frame, frame.contains(cursor),
                  hypot(point.x - cursor.x, point.y - cursor.y) < 5 else {
                self.window.ignoresMouseEvents = true
                self.nextHitTest = 0
                return
            }
            self.window.ignoresMouseEvents = (try? result.get() as? Bool) != true
        }
    }

    private func count() -> UInt32 {
        CGEventSource.counterForEventType(.combinedSessionState, eventType: .keyDown)
    }

    private func poll() {
        let current = count()
        guard ready else { return }
        setKeyDisplay(typingPad.canShowKeys)
        if current != previousCount {
            previousCount = current
            if !displayingKeys { web.evaluateJavaScript("pet.tap()", completionHandler: nil) }
        }

        let mouse = MouseSample()
        refreshDragRegion(at: mouse.point, buttons: mouse.buttons)
        let old = previousMouse
        guard mouse != old else { return }
        previousMouse = mouse
        let point = mouse.point
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? window.screen else { return }
        let display = screen.frame
        let panel = window.frame
        let sample: [String: Any] = [
            "moved": point != old.point,
            "nx": (point.x - display.minX) / display.width,
            "ny": (display.maxY - point.y) / display.height,
            "rx": (point.x - panel.minX) / panel.width,
            "ry": (panel.maxY - point.y) / panel.height,
            "buttons": mouse.buttons,
            "before": old.buttons,
            "leftClick": mouse.left != old.left,
            "rightClick": mouse.right != old.right,
            "scrolled": mouse.wheel != old.wheel
        ]
        web.callAsyncJavaScript("pet.pointer(sample)", arguments: ["sample": sample], in: nil, in: .page, completionHandler: nil)
    }

    private func setKeyDisplay(_ enabled: Bool, force: Bool = false) {
        guard ready, force || enabled != displayingKeys else { return }
        displayingKeys = enabled
        previousCount = count()
        web.evaluateJavaScript(enabled ? "pet.practice(true)" : "pet.practice(false)", completionHandler: nil)
    }

    func windowDidResignKey(_ notification: Notification) { setKeyDisplay(false) }
    func windowWillClose(_ notification: Notification) { setKeyDisplay(false) }
    func applicationDidResignActive(_ notification: Notification) { setKeyDisplay(false) }

    @objc func openTypingWindow() {
        if typingWindow == nil {
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 120),
                                 styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            panel.title = "KuroCat 打字窗口"
            panel.isReleasedWhenClosed = false
            panel.contentView = typingPad
            panel.delegate = self
            let hint = NSTextField(wrappingLabelWithString: "在这里敲键，看看猫爪和尾巴。切到其他窗口后，字母会消失。")
            hint.font = .systemFont(ofSize: 16)
            hint.translatesAutoresizingMaskIntoConstraints = false
            typingPad.addSubview(hint)
            NSLayoutConstraint.activate([
                hint.leadingAnchor.constraint(equalTo: typingPad.leadingAnchor, constant: 24),
                hint.trailingAnchor.constraint(equalTo: typingPad.trailingAnchor, constant: -24),
                hint.centerYAnchor.constraint(equalTo: typingPad.centerYAnchor)
            ])
            typingPad.keyChanged = { [weak self] vk, down, repeating in
                guard let self, self.ready, self.typingPad.canShowKeys else { return }
                self.setKeyDisplay(true)
                self.web.callAsyncJavaScript("pet.key(vk, down, repeating)", arguments: [
                    "vk": vk, "down": down, "repeating": repeating
                ], in: nil, in: .page, completionHandler: nil)
            }
            typingPad.lostFocus = { [weak self] in self?.setKeyDisplay(false) }
            panel.center()
            typingWindow = panel
        }
        NSApp.activate(ignoringOtherApps: true)
        typingWindow?.makeKeyAndOrderFront(nil)
        typingWindow?.makeFirstResponder(typingPad)
        setKeyDisplay(typingPad.canShowKeys)
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "打开打字窗口", action: #selector(openTypingWindow), keyEquivalent: "").target = self
        let sizeItem = NSMenuItem()
        let controls = NSView(frame: NSRect(x: 0, y: 0, width: 218, height: 54))
        sizeLabel.stringValue = "桌宠大小  \(window.scalePercent)%"
        sizeLabel.frame = NSRect(x: 16, y: 29, width: 186, height: 18)
        controls.addSubview(sizeLabel)
        let slider = NSSlider(value: Double(window.scalePercent), minValue: 20, maxValue: 150,
                              target: self, action: #selector(changeSize(_:)))
        slider.frame = NSRect(x: 14, y: 6, width: 190, height: 20)
        slider.isContinuous = true
        slider.setAccessibilityLabel("桌宠大小，百分比")
        controls.addSubview(slider)
        sizeItem.view = controls
        menu.addItem(sizeItem)
        menu.addItem(.separator())
        for option in skins {
            guard let id = option["id"], let name = option["name"] else { continue }
            let item = menu.addItem(withTitle: name, action: #selector(selectSkin(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = id
            item.state = id == skin ? .on : .off
        }
        menu.addItem(.separator())
        let mode = menu.addItem(withTitle: "3D 外观", action: #selector(toggleModel), keyEquivalent: "")
        mode.target = self
        mode.state = use3D ? .on : .off
        menu.addItem(withTitle: "退出 KuroCat Offline", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        status.menu = menu
    }

    @objc private func changeSize(_ sender: NSSlider) {
        window.resize(to: Int(sender.doubleValue.rounded()))
        sizeLabel.stringValue = "桌宠大小  \(window.scalePercent)%"
    }

    @objc private func selectSkin(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        defaults.set(id, forKey: "skin")
        applyAppearance()
        rebuildMenu()
    }

    @objc private func toggleModel() {
        defaults.set(!use3D, forKey: "use3D")
        applyAppearance()
        rebuildMenu()
    }
}
