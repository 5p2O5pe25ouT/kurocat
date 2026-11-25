import AppKit
import WebKit

final class Pet: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    let web: WKWebView = {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        return WKWebView(frame: .zero, configuration: config)
    }()
    private let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 344, height: 310),
                                 styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
    private let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let defaults = UserDefaults.standard
    private var skins: [[String: String]] = []
    private var timer: Timer?
    private var previousCount: UInt32 = 0
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
        if let screen = NSScreen.main {
            window.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - window.frame.width - 12,
                                          y: screen.visibleFrame.minY + 12))
        }
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
            self.previousCount = self.count()
            if self.timer?.isValid != true {
                let timer = Timer(timeInterval: 0.065, repeats: true) { [weak self] _ in self?.poll() }
                timer.tolerance = 0.015
                RunLoop.main.add(timer, forMode: .common)
                self.timer = timer
            }
        }
    }

    private func count() -> UInt32 {
        CGEventSource.counterForEventType(.combinedSessionState, eventType: .keyDown)
    }

    private func poll() {
        let current = count()
        defer { previousCount = current }
        guard ready, current != previousCount else { return }
        web.evaluateJavaScript("pet.tap()", completionHandler: nil)
    }

    private func rebuildMenu() {
        let menu = NSMenu()
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
