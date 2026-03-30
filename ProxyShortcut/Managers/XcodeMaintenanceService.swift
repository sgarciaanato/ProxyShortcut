import Foundation

class XcodeMaintenanceService {
    private let derivedDataPath = NSString(
        string: "~/Library/Developer/Xcode/DerivedData"
    ).expandingTildeInPath

    private let xcodeCachePath = NSString(
        string: "~/Library/Caches/com.apple.dt.Xcode"
    ).expandingTildeInPath

    private let heavyProcesses = [
        "SourceKitService",     // Indexado + autocompletado — el más pesado
        "XCBBuildService",      // Build system
        "XCBIndexOperation",    // Indexado en background
        "IDEHelperService",     // Helper del IDE
        "XCBuildServiceProxy"   // Proxy del build service
    ]

    func clean() {
        clearDerivedData()
        clearXcodeCache()
        killHeavyProcesses()
        print("[XcodeMaintenanceService] Limpieza completada.")
    }

    private func clearDerivedData() {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: derivedDataPath) else { return }

        // Detectar carpetas que Xcode tiene abiertas en este momento via lsof.
        // Evita borrar el proyecto que se está compilando actualmente.
        let openFolders = derivedDataFoldersOpenByXcode()

        // Excluir también ModuleCache.noindex — tarda mucho en regenerarse
        // y no contribuye al uso de RAM.
        let excluded = openFolders.union(["ModuleCache.noindex"])
        let toDelete = contents.filter { !excluded.contains($0) }

        for item in toDelete {
            let fullPath = (derivedDataPath as NSString).appendingPathComponent(item)
            try? fileManager.removeItem(atPath: fullPath)
        }

        if !openFolders.isEmpty {
            print("[XcodeMaintenanceService] Skipped \(openFolders.count) proyecto(s) abierto(s): \(openFolders.joined(separator: ", "))")
        }
        print("[XcodeMaintenanceService] DerivedData vaciado (\(toDelete.count) carpetas)")
    }

    // Detecta qué carpetas de DerivedData están en uso consultando todos los procesos
    // relacionados con Xcode. SourceKitService siempre tiene el índice del proyecto
    // activo abierto, lo que hace la detección confiable incluso entre builds.
    private func derivedDataFoldersOpenByXcode() -> Set<String> {
        let xcodeProcesses = [
            "Xcode",
            "SourceKitService",   // siempre tiene el índice del proyecto activo abierto
            "XCBBuildService",
            "XCBIndexOperation",
            "IDEHelperService",
            "XCBuildServiceProxy"
        ]

        var folders = Set<String>()

        for process in xcodeProcesses {
            let task = Process()
            task.launchPath = "/usr/sbin/lsof"
            task.arguments = ["-c", process]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()

            do {
                try task.run()
                task.waitUntilExit()
            } catch { continue }

            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

            for line in output.components(separatedBy: "\n") {
                guard let range = line.range(of: "DerivedData/") else { continue }
                let afterMarker = String(line[range.upperBound...])
                let folder = afterMarker.components(separatedBy: "/").first ?? ""
                if !folder.isEmpty {
                    folders.insert(folder)
                }
            }
        }

        return folders
    }

    private func clearXcodeCache() {
        try? FileManager.default.removeItem(atPath: xcodeCachePath)
    }

    private func killHeavyProcesses() {
        for process in heavyProcesses {
            let task = Process()
            task.launchPath = "/usr/bin/killall"
            task.arguments = ["-9", process]
            try? task.run()
            task.waitUntilExit()
        }
    }
}
