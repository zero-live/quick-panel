//
//  PanelView.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import SwiftUI

struct AppItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let iconName: String
}

struct PanelView: View {
    // Hardcoded test apps for MVP
    let testApps: [AppItem] = [
        AppItem(name: "Safari", path: "/Applications/Safari.app", iconName: "safari"),
        AppItem(name: "Mail", path: "/Applications/Mail.app", iconName: "envelope"),
        AppItem(name: "Calendar", path: "/System/Applications/Calendar.app", iconName: "calendar"),
        AppItem(name: "Notes", path: "/System/Applications/Notes.app", iconName: "note.text"),
        AppItem(name: "Music", path: "/System/Applications/Music.app", iconName: "music.note"),
        AppItem(name: "Photos", path: "/System/Applications/Photos.app", iconName: "photo"),
        AppItem(name: "Messages", path: "/System/Applications/Messages.app", iconName: "message"),
        AppItem(name: "FaceTime", path: "/System/Applications/FaceTime.app", iconName: "video"),
        AppItem(name: "Finder", path: "/System/Library/CoreServices/Finder.app", iconName: "folder"),
        AppItem(name: "Terminal", path: "/System/Applications/Utilities/Terminal.app", iconName: "terminal"),
        AppItem(name: "Settings", path: "/System/Applications/System Settings.app", iconName: "gearshape"),
        AppItem(name: "App Store", path: "/System/Applications/App Store.app", iconName: "bag")
    ]

    let columns = Array(repeating: GridItem(.fixed(70), spacing: 16), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            // Upper grid - 3 rows x 4 columns
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(testApps) { app in
                    AppIconButton(app: app)
                }
            }
            .padding(20)
        }
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

struct AppIconButton: View {
    let app: AppItem
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: app.iconName)
                .font(.system(size: 36))
                .foregroundColor(.primary)
                .frame(width: 60, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isHovered ? Color.primary.opacity(0.1) : Color.clear)
                )

            Text(app.name)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(.primary)
                .frame(maxWidth: 70)
        }
        .frame(width: 70, height: 90)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            AppLauncher.shared.launchApp(at: app.path)
        }
    }
}

#Preview {
    PanelView()
        .frame(width: 360, height: 340)
}
