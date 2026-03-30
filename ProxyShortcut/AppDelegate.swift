import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    // MARK: - Status Bar

    private var statusItem: NSStatusItem?

    // MARK: - Managers

    private let proxyManager = ProxyManager()
    private let memoryMonitor = MemoryMonitor()
    private let displaySleepManager = DisplaySleepManager()
    private let xcodeService = XcodeMaintenanceService()

    // MARK: - Menu state refs

    private var caffeinateItem: NSMenuItem?
    private var proxyMenuItems: [NSMenuItem] = []

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupManagers()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "hammer", accessibilityDescription: "Menu Bar Icon")
        button.action = #selector(showMenu)
        button.target = self
    }

    private func setupManagers() {
        memoryMonitor.onUpdate = { [weak self] percent in
            DispatchQueue.main.async { self?.updateTitle(memory: percent) }
        }
        memoryMonitor.start()

        proxyManager.onProxyChanged = { [weak self] in
            self?.proxyManager.checkAndFixAutoProxy()
        }
        proxyManager.setupMonitor()
    }

    private func updateTitle(memory: Int) {
        statusItem?.button?.title = "\(memory)%"
        statusItem?.button?.imagePosition = .imageLeft
    }

    // MARK: - Menu

    @objc func showMenu() {
        let menu = NSMenu()
        menu.delegate = self
        proxyMenuItems = []

        for (index, proxy) in Proxy.all.enumerated() {
            let item = NSMenuItem(title: proxy.name, action: #selector(toggleProxy(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            menu.addItem(item)
            proxyMenuItems.append(item)
        }

        let toggleBoth = NSMenuItem(title: "toggle HTTP & HTTPS", action: #selector(toggleHttpAndHttps), keyEquivalent: "d")
        toggleBoth.target = self
        menu.addItem(toggleBoth)
        menu.addItem(.separator())

        let zoomItem = NSMenuItem(title: "cl.mobile", action: #selector(openZoomRoom), keyEquivalent: "z")
        zoomItem.target = self
        menu.addItem(zoomItem)
        menu.addItem(.separator())

        caffeinateItem = NSMenuItem(title: "caffeinate -d", action: #selector(toggleCaffeinate), keyEquivalent: "c")
        caffeinateItem?.target = self
        menu.addItem(caffeinateItem!)
        menu.addItem(.separator())

        let cleanItem = NSMenuItem(title: "clean Xcode", action: #selector(cleanXcode), keyEquivalent: "k")
        cleanItem.target = self
        menu.addItem(cleanItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Salir", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateTitle(memory: memoryMonitor.availablePercent)
        caffeinateItem?.state = displaySleepManager.isActive ? .on : .off
        for (index, proxy) in Proxy.all.enumerated() {
            proxyMenuItems[index].state = proxyManager.getStatus(for: proxy) ? .on : .off
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        memoryMonitor.refresh()
    }

    // MARK: - Actions

    @objc func toggleProxy(_ sender: NSMenuItem) {
        let proxy = Proxy.all[sender.tag]
        proxyManager.toggle(proxy: proxy, currentlyEnabled: sender.state == .on)
    }

    @objc func toggleHttpAndHttps() {
        let http = Proxy.all[1]
        let https = Proxy.all[2]
        let enabled = proxyManager.getStatus(for: http)
        proxyManager.toggle(proxy: http, currentlyEnabled: enabled)
        proxyManager.toggle(proxy: https, currentlyEnabled: enabled)
    }

    @objc func openZoomRoom() {
        guard let url = URL(string: "https://walmart.zoom.us/my/cl.mobile") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func toggleCaffeinate() {
        displaySleepManager.toggle()
    }

    @objc func cleanXcode() {
        xcodeService.clean()
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}
