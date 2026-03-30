import Foundation
import Darwin

class MemoryMonitor {
    private var timer: Timer?
    private let interval: TimeInterval

    // Porcentaje de memoria disponible antes de que macOS empiece a forzar cierres.
    // Equivale a lo que Activity Monitor muestra como "Memory Available":
    //   free + inactive + speculative + purgeable
    // Cuando baja de ~10%, macOS entra en presión roja y puede matar procesos.
    private(set) var availablePercent: Int = 0
    var onUpdate: ((Int) -> Void)?

    init(interval: TimeInterval = 30.0) {
        self.interval = interval
    }

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        availablePercent = calculateAvailablePercent()
        onUpdate?(availablePercent)
    }

    // Calcula qué % de RAM puede reclamar macOS antes de matar procesos.
    // Fórmula: (free + inactive + speculative + purgeable) / total
    //
    // Referencia de umbrales:
    //   > 20% — sin presión
    //   10–20% — macOS comprime activamente
    //   5–10% — presión amarilla (Activity Monitor)
    //   < 5%  — presión roja, macOS puede forzar cierres
    private func calculateAvailablePercent() -> Int {
        var size = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        var stats = vm_statistics64_data_t()

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        let pageSize = UInt64(vm_kernel_page_size)
        let available = UInt64(
            stats.free_count +
            stats.inactive_count +
            stats.speculative_count +
            stats.purgeable_count
        ) * pageSize
        let total = ProcessInfo.processInfo.physicalMemory

        return max(0, min(100, Int(Double(available) / Double(total) * 100)))
    }
}
