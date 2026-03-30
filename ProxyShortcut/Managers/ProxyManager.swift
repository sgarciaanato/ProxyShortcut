import Foundation
import SystemConfiguration

class ProxyManager {
    private let interface: String
    private var dynamicStore: SCDynamicStore?

    var onProxyChanged: (() -> Void)?

    init(interface: String = "Wi-Fi") {
        self.interface = interface
    }

    func setupMonitor() {
        var context = SCDynamicStoreContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil, release: nil, copyDescription: nil
        )

        dynamicStore = SCDynamicStoreCreate(nil, "ProxyMonitor" as CFString, { (_, _, info) in
            guard let info = info else { return }
            let manager = Unmanaged<ProxyManager>.fromOpaque(info).takeUnretainedValue()
            DispatchQueue.main.async { manager.onProxyChanged?() }
        }, &context)

        guard let store = dynamicStore else { return }
        let key = SCDynamicStoreKeyCreateProxies(nil)
        SCDynamicStoreSetNotificationKeys(store, [key] as CFArray, nil)

        if let source = SCDynamicStoreCreateRunLoopSource(nil, store, 0) {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
    }

    func checkAndFixAutoProxy() {
        let autoProxy = Proxy.all[0]
        if getStatus(for: autoProxy) {
            forceState(for: autoProxy, enabled: false)
        }
    }

    func getStatus(for proxy: Proxy) -> Bool {
        let output = runNetworkSetup(arguments: [proxy.getCommand, interface])
        return output?.contains("Enabled: Yes") ?? false
    }

    func toggle(proxy: Proxy, currentlyEnabled: Bool) {
        let state = currentlyEnabled ? "off" : "on"
        runNetworkSetup(arguments: [proxy.setCommand, interface, state])
    }

    func forceState(for proxy: Proxy, enabled: Bool) {
        runNetworkSetup(arguments: [proxy.setCommand, interface, enabled ? "on" : "off"])
    }

    @discardableResult
    private func runNetworkSetup(arguments: [String]) -> String? {
        let task = Process()
        task.launchPath = "/usr/sbin/networksetup"
        task.arguments = arguments

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            print("[ProxyManager] Error running networksetup: \(error)")
            return nil
        }
    }
}
