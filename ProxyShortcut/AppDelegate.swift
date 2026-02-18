//
//  AppDelegate.swift
//  ProxyShortcut
//
//  Created by Samuel Garcia on 25-09-25.
//

import Cocoa
import Darwin
import Foundation
import IOKit.pwr_mgt
import SwiftUI
import SystemConfiguration

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem?
    var interface: String = "Wi-Fi"
    var timer: Timer?
    var secondsElapsed = 60
    var fullScreenController: FullScreenWindowController?
    var assertionID: IOPMAssertionID = 0
    var caffeinateItem: NSMenuItem!
    var deepCleanXcodeItem: NSMenuItem!
    var isCaffeinated = false
    var dynamicStore: SCDynamicStore?
    var freePercent: Int = 0

    func setupProxyMonitor() {
        var context = SCDynamicStoreContext(version: 0, info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), retain: nil, release: nil, copyDescription: nil)

        // Creamos el store con un callback
        dynamicStore = SCDynamicStoreCreate(nil, "ProxyMonitor" as CFString, { (store, keys, info) in
            guard let info = info else { return }

            // Recuperamos la instancia de AppDelegate
            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(info).takeUnretainedValue()

            // Ejecutar en el hilo principal para interactuar con networksetup
            DispatchQueue.main.async {
                appDelegate.checkAndFixProxies()
            }
        }, &context)

        // Registramos la llave que observa cambios en Proxies
        let key = SCDynamicStoreKeyCreateProxies(nil)
        SCDynamicStoreSetNotificationKeys(dynamicStore!, [key] as CFArray, nil)

        // Añadir al run loop actual
        let runLoopSource = SCDynamicStoreCreateRunLoopSource(nil, dynamicStore!, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    }

    func checkAndFixProxies() {
        print("Cambio detectado en la configuración de red. Verificando proxies...")

        for proxy in proxies {
            let isEnabled = getProxyStatus(proxy: proxy, interface: interface)

            // EJEMPLO: Si quieres que siempre estén OFF
            if isEnabled, proxy.name == "Automatic proxy configuration" {
                print("\(proxy.name) detectado como ON. Revirtiendo a OFF...")
                forceProxyState(proxy: proxy, state: "off")
            }
        }
    }

    // Función auxiliar para no depender de un NSMenuItem
    func forceProxyState(proxy: Proxy, state: String) {
        let task = Process()
        task.launchPath = "/usr/sbin/networksetup"
        task.arguments = [proxy.setCommand, interface, state]
        try? task.run()
        task.waitUntilExit()
    }

    func getFreeMemoryPercentage() -> Int {
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var stats = vm_statistics64_data_t()

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }

        if result == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            // macOS considera "usada" la memoria Activa + Wired + Comprimida
            let used = UInt64(stats.active_count + stats.wire_count + stats.compressor_page_count) * pageSize
            let total = ProcessInfo.processInfo.physicalMemory

            return Int((1.0 - Double(used) / Double(total)) * 100)
        }
        return 0
    }

    var memoryTimer: Timer?

    func monitor() {
        freePercent = getFreeMemoryPercentage()

        // Actualizamos la UI en el hilo principal
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            var title = "\(freePercent)%"
            if secondsElapsed > 0, timer != nil {
                title += " (\(secondsElapsed)s)"
            }
            statusItem?.button?.title = title
            // Opcional: Cambiar el icono según el estado
            statusItem?.button?.imagePosition = .imageLeft
        }
    }

    func startMemoryMonitor() {
        // Actualiza cada 3 segundos
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            monitor()
        }
    }

    struct Proxy {
        let name: String
        let getCommand: String
        let setCommand: String
    }

    let proxies: [Proxy] = [
        Proxy(
            name: "Automatic proxy configuration",
            getCommand: "getautoproxyurl",
            setCommand: "setautoproxystate"
        ),
        Proxy(
            name: "Web proxy (HTTP)",
            getCommand: "getwebproxy",
            setCommand: "setwebproxystate"
        ),
        Proxy(
            name: "Secure web proxy (HTTPS)",
            getCommand: "getsecurewebproxy",
            setCommand: "setsecurewebproxystate"
        )
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "hammer", accessibilityDescription: "Menu Bar Icon")
            button.action = #selector(showMenu)
            button.target = self
        }
        setupProxyMonitor()
        startMemoryMonitor()
        monitor()
    }

    @objc func showMenu() {
        let menu = NSMenu()

        for (index, proxy) in proxies.enumerated() {
            let proxyToggleItem = NSMenuItem(title: proxy.name, action: #selector(toggleProxy), keyEquivalent: "")
            proxyToggleItem.target = self
            proxyToggleItem.tag = index
            menu.delegate = self
            menu.addItem(proxyToggleItem)
        }
        menu.addItem(NSMenuItem.separator())
        let zoomItem = NSMenuItem(title: "cl.mobile", action: #selector(openZoomRoom), keyEquivalent: "z")
        zoomItem.target = self
        menu.addItem(zoomItem)
        menu.addItem(NSMenuItem.separator())
        caffeinateItem = NSMenuItem(title: "caffeinate -d", action: #selector(toggleCaffeinate), keyEquivalent: "c")
        caffeinateItem.target = self
        menu.addItem(caffeinateItem)
        menu.addItem(NSMenuItem.separator())
        deepCleanXcodeItem = NSMenuItem(title: "clean Xcode", action: #selector(deepCleanXcode), keyEquivalent: "k")
        deepCleanXcodeItem.target = self
        menu.addItem(deepCleanXcodeItem)
        menu.addItem(NSMenuItem.separator())
        let timerItem = NSMenuItem(title: "Start Timer", action: #selector(startTimer), keyEquivalent: "t")
        timerItem.target = self
        menu.addItem(timerItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Salir", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
    }

    func menuWillOpen(_ menu: NSMenu) {
        timer?.invalidate()
        statusItem?.button?.title = "\(freePercent)%"
        secondsElapsed = 0
        caffeinateItem?.state = isCaffeinated ? .on : .off
        for (index, proxy) in proxies.enumerated() {
            menu.item(at: index)?.state = getProxyStatus(proxy: proxy, interface: interface) ? .on : .off
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        monitor()
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

    @objc func toggleProxy(_ sender: NSMenuItem) {
        let task = Process()
        let type = proxies[sender.tag].setCommand
        task.launchPath = "/usr/sbin/networksetup"
        let state = sender.state == .on ? "off" : "on"
        task.arguments = [type, interface, state]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            print("Error al ejecutar el comando: \(error)")
        }
    }

    @objc func openZoomRoom() {
        let zoomRoomURL = URL(string: "https://walmart.zoom.us/my/cl.mobile")!
        NSWorkspace.shared.open(zoomRoomURL)
    }

    @objc func toggleCaffeinate() {
        if isCaffeinated {
            IOPMAssertionRelease(assertionID)
            isCaffeinated = false
        } else {
            let reasonForActivity = "Prevent display sleep" as CFString
            IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                        IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                        reasonForActivity,
                                        &assertionID)
            isCaffeinated = true
        }
    }

    @objc func deepCleanXcode() {
        print("Iniciando limpieza profunda de Xcode...")

        let paths = [
            "~/Library/Developer/Xcode/DerivedData/*",
            "~/Library/Caches/com.apple.dt.Xcode"
        ]

        // 1. Borrar carpetas de caché y datos derivados
        for path in paths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            let task = Process()
            task.launchPath = "/bin/rm"
            task.arguments = ["-rf", expandedPath]
            try? task.run()
            task.waitUntilExit()
        }

        // 2. Matar SourceKitService (Xcode lo reinicia automáticamente)
        let killTask = Process()
        killTask.launchPath = "/usr/bin/killall"
        killTask.arguments = ["-9", "SourceKitService"]
        try? killTask.run()
        killTask.waitUntilExit()

        print("Limpieza completada. Derived Data eliminado y SourceKitService reiniciado.")
    }

    @objc func startTimer() {
        secondsElapsed = 60
        timer?.invalidate()
        statusItem?.button?.title = "\(secondsElapsed)"
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateTitle), userInfo: nil, repeats: true)
    }

    @objc func updateTitle() {
        guard let statusItem else { return }
        if secondsElapsed > 0 {
            secondsElapsed -= 1
            statusItem.button?.title = "\(freePercent)% (\(secondsElapsed)s)"
        } else {
            timer?.invalidate()
            statusItem.button?.title = "\(freePercent)%"
            showFullScreenImage()
        }
    }

    func getProxyStatus(proxy: Proxy, interface: String) -> Bool {
        let task = Process()
        task.launchPath = "/usr/sbin/networksetup"
        let command = proxy.getCommand
        task.arguments = [command, interface]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output.contains("Enabled: Yes")
            }
        } catch {
            print("Error al ejecutar el comando: \(error)")
        }

         return false
    }

    func showFullScreenImage() {
        // Cambia el nombre "ejemplo.png" por la imagen que desees mostrar
        guard let image = NSImage(named: "old-men-angry") else {
            print("Imagen no encontrada")
            return
        }
        fullScreenController = FullScreenWindowController(image: image)
        fullScreenController?.show()
    }
}

class FullScreenWindowController: NSWindowController {
    let closeButton = NSButton()

    convenience init(image: NSImage) {
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let window = NSWindow(contentRect: screenFrame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = .mainMenu + 1
        window.isOpaque = true
        window.backgroundColor = .black
        window.collectionBehavior = [.canJoinAllSpaces]

        // ImageView
        let imageView = NSImageView(frame: screenFrame)
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        window.contentView = imageView

        self.init(window: window)

        // Close Button
        let buttonSize: CGFloat = 44
        closeButton.frame = NSRect(
            x: screenFrame.width - buttonSize - 24,
            y: screenFrame.height - buttonSize - 24,
            width: buttonSize,
            height: buttonSize
        )
        closeButton.bezelStyle = .regularSquare
        closeButton.title = "✕"
        closeButton.font = NSFont.systemFont(ofSize: 28)
        closeButton.isBordered = false
        closeButton.wantsLayer = true
        closeButton.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        closeButton.layer?.cornerRadius = buttonSize / 2
        closeButton.contentTintColor = .white
        closeButton.action = #selector(closeWindow)
        closeButton.target = self

        imageView.addSubview(closeButton)
    }

    func show() {
        // Solo ocupa toda la pantalla, pero no entra en modo "full screen" de macOS
        if let screenFrame = NSScreen.main?.frame {
            window?.setFrame(screenFrame, display: true)
        }
        window?.makeKeyAndOrderFront(nil)
    }

    @objc func closeWindow() {
        window?.close()
    }
}
