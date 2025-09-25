//
//  ProxyShortcutApp.swift
//  ProxyShortcut
//
//  Created by Samuel Garcia on 25-09-25.
//

import SwiftUI

@main
struct ProxyShortcutApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
