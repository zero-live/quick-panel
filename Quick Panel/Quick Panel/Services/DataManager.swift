//
//  DataManager.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Foundation
import Combine

class DataManager: ObservableObject {
    static let shared = DataManager()

    @Published var items: [PanelItem] = []

    private let configDirectory: URL
    private let configFile: URL

    private init() {
        // Setup config directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        configDirectory = appSupport.appendingPathComponent("Quick Panel")
        configFile = configDirectory.appendingPathComponent("config.json")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)

        // Load data
        loadItems()

        // If no items, create default ones
        if items.isEmpty {
            createDefaultItems()
        }
    }

    // MARK: - Load/Save

    func loadItems() {
        guard FileManager.default.fileExists(atPath: configFile.path) else {
            print("📂 No config file found, will create defaults")
            return
        }

        do {
            let data = try Data(contentsOf: configFile)
            items = try JSONDecoder().decode([PanelItem].self, from: data)
            print("✅ Loaded \(items.count) items from config")
        } catch {
            print("❌ Failed to load config: \(error.localizedDescription)")
        }
    }

    func saveItems() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(items)
            try data.write(to: configFile)
            print("✅ Saved \(items.count) items to config")
        } catch {
            print("❌ Failed to save config: \(error.localizedDescription)")
        }
    }

    // MARK: - CRUD Operations

    func addItem(_ item: PanelItem) {
        items.append(item)
        saveItems()
    }

    func updateItem(_ item: PanelItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            saveItems()
        }
    }

    func deleteItem(_ item: PanelItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }

    func moveItem(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              sourceIndex >= 0, sourceIndex < items.count,
              destinationIndex >= 0, destinationIndex <= items.count else {
            return
        }

        let item = items.remove(at: sourceIndex)
        items.insert(item, at: destinationIndex)

        // Update order indices
        for (index, _) in items.enumerated() {
            items[index].order = index
        }
        saveItems()
    }

    // MARK: - Default Items

    private func createDefaultItems() {
        print("📝 Creating default items...")

        let defaultApps: [(String, String)] = [
            ("Safari", "/Applications/Safari.app"),
            ("Mail", "/Applications/Mail.app"),
            ("Calendar", "/System/Applications/Calendar.app"),
            ("Notes", "/System/Applications/Notes.app"),
            ("Music", "/System/Applications/Music.app"),
            ("Photos", "/System/Applications/Photos.app"),
            ("Messages", "/System/Applications/Messages.app"),
            ("FaceTime", "/System/Applications/FaceTime.app"),
            ("Finder", "/System/Library/CoreServices/Finder.app"),
            ("Terminal", "/System/Applications/Utilities/Terminal.app"),
            ("Settings", "/System/Applications/System Settings.app"),
            ("App Store", "/System/Applications/App Store.app")
        ]

        for (index, (name, path)) in defaultApps.enumerated() {
            let item = PanelItem(
                name: name,
                type: .application,
                path: path,
                order: index
            )
            items.append(item)
        }

        saveItems()
        print("✅ Created \(items.count) default items")
    }
}
