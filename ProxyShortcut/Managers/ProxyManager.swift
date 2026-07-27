import Foundation
import SystemConfiguration

class ProxyManager {
    private let interface: String
    private let stateStore = ProxyStateStore()
    private var dynamicStore: SCDynamicStore?
    private var pendingEnforcement: DispatchWorkItem?

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
            DispatchQueue.main.async { manager.scheduleEnforcement() }
        }, &context)

        guard let store = dynamicStore else { return }
        let key = SCDynamicStoreKeyCreateProxies(nil)
        SCDynamicStoreSetNotificationKeys(store, [key] as CFArray, nil)

        if let source = SCDynamicStoreCreateRunLoopSource(nil, store, 0) {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
    }

    /// Al conectar la VPN llegan varias notificaciones seguidas: las agrupamos
    /// para no pelear con quien esté escribiendo la configuración en ese momento.
    private func scheduleEnforcement() {
        pendingEnforcement?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.enforceDesiredState() }
        pendingEnforcement = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    func enforceDesiredState() {
        for proxy in Proxy.all {
            let desired = stateStore.desiredState(for: proxy)
            guard getStatus(for: proxy) != desired else { continue }
            apply(enabled: desired, to: proxy)
        }
    }

    func getStatus(for proxy: Proxy) -> Bool {
        let output = runNetworkSetup(arguments: [proxy.getCommand, interface])
        return output?.contains("Enabled: Yes") ?? false
    }

    func toggle(proxy: Proxy, currentlyEnabled: Bool) {
        setState(enabled: !currentlyEnabled, for: proxy)
    }

    /// Cambio pedido por el usuario: pasa a ser el estado deseado.
    func setState(enabled: Bool, for proxy: Proxy) {
        stateStore.setDesiredState(enabled, for: proxy)
        apply(enabled: enabled, to: proxy)
    }

    private func apply(enabled: Bool, to proxy: Proxy) {
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
