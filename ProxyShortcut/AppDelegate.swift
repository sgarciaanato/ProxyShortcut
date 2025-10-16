//
//  AppDelegate.swift
//  ProxyShortcut
//
//  Created by Samuel Garcia on 25-09-25.
//

import Cocoa
import Foundation
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem?
    var interface: String = "Wi-Fi"
    var timer: Timer?
    var secondsElapsed = 60
    var fullScreenController: FullScreenWindowController?

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
            name: "Automatic proxy configuration",
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
        let timerItem = NSMenuItem(title: "Start Timer", action: #selector(startTimer), keyEquivalent: "")
        timerItem.target = self
        menu.addItem(timerItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Salir", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
    }

    func menuWillOpen(_ menu: NSMenu) {
        timer?.invalidate()
        statusItem?.button?.title = ""
        for (index, proxy) in proxies.enumerated() {
            menu.item(at: index)?.state = getProxyStatus(proxy: proxy, interface: interface) ? .on : .off
        }
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
            statusItem.button?.title = "\(secondsElapsed)"
        } else {
            timer?.invalidate()
            statusItem.button?.title = ""
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
    let closeButton: NSButton = NSButton()

    convenience init(image: NSImage) {
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let window = NSWindow(contentRect: screenFrame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = .mainMenu + 1
        window.isOpaque = true
        window.backgroundColor = .black
        window.collectionBehavior = [.fullScreenPrimary]

        self.init(window: window)

        // ImageView
        let imageView = NSImageView(frame: screenFrame)
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        window.contentView = imageView

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
        window?.makeKeyAndOrderFront(nil)
        window?.toggleFullScreen(nil)
    }

    @objc func closeWindow() {
        window?.close()
    }
}
