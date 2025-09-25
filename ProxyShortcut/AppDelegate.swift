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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
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
        menu.addItem(NSMenuItem(title: "Salir", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
    }

    func menuWillOpen(_ menu: NSMenu) {
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
}
