//
//  Quick_PanelApp.swift
//  Quick Panel
//
//  Created by 本心 on 2025/12/27.
//

import SwiftUI

@main
struct Quick_PanelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Use Settings instead of WindowGroup to avoid showing default window
        Settings {
            EmptyView()
        }
    }
}
