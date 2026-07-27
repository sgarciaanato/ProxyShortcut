import Foundation

/// Recuerda el estado que el usuario eligió para cada proxy.
/// Si nunca se tocó desde el menú, el estado deseado es apagado.
struct ProxyStateStore {
    private let defaults = UserDefaults.standard

    func desiredState(for proxy: Proxy) -> Bool {
        defaults.bool(forKey: key(for: proxy))
    }

    func setDesiredState(_ enabled: Bool, for proxy: Proxy) {
        defaults.set(enabled, forKey: key(for: proxy))
    }

    private func key(for proxy: Proxy) -> String {
        "desiredProxyState.\(proxy.id)"
    }
}
