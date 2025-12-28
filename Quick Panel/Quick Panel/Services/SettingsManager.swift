//
//  SettingsManager.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Foundation
import Combine

// MARK: - AppSettings Model

struct AppSettings: Codable, Equatable {
    var gridColumns: Int = 4        // 2-6
    var gridRows: Int = 3           // 2-5
    var itemSpacing: CGFloat = 16   // 8-24
    var panelOpacity: Double = 1.0  // 0.5-1.0
    var launchAtLogin: Bool = false

    // Computed properties
    var itemsPerPage: Int {
        gridColumns * gridRows
    }

    var panelWidth: CGFloat {
        CGFloat(gridColumns) * 70 + CGFloat(gridColumns - 1) * itemSpacing + 40
    }

    var layerHeight: CGFloat {
        CGFloat(gridRows) * 90 + CGFloat(gridRows - 1) * itemSpacing + 48
    }

    // Validation
    mutating func validate() {
        gridColumns = max(2, min(6, gridColumns))
        gridRows = max(2, min(5, gridRows))
        itemSpacing = max(8, min(24, itemSpacing))
        panelOpacity = max(0.5, min(1.0, panelOpacity))
    }

    static var `default`: AppSettings {
        return AppSettings()
    }
}

// MARK: - SettingsManager

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var settings: AppSettings {
        didSet {
            var validatedSettings = settings
            validatedSettings.validate()
            if validatedSettings != settings {
                settings = validatedSettings
                return
            }
            saveSettings()
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        }
    }

    private let configDirectory: URL
    private let settingsFile: URL

    private init() {
        // Setup config directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        configDirectory = appSupport.appendingPathComponent("Quick Panel")
        settingsFile = configDirectory.appendingPathComponent("settings.json")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)

        // Load settings
        self.settings = AppSettings.default
        loadSettings()

        print("⚙️ Settings loaded: \(settings.gridColumns)x\(settings.gridRows) grid")
    }

    // MARK: - Load/Save

    private func loadSettings() {
        guard FileManager.default.fileExists(atPath: settingsFile.path) else {
            print("📂 No settings file found, using defaults")
            return
        }

        do {
            let data = try Data(contentsOf: settingsFile)
            var loadedSettings = try JSONDecoder().decode(AppSettings.self, from: data)
            loadedSettings.validate()
            settings = loadedSettings
            print("✅ Loaded settings from file")
        } catch {
            print("❌ Failed to load settings: \(error.localizedDescription)")
            print("   Using default settings")
        }
    }

    private func saveSettings() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try data.write(to: settingsFile)
            print("✅ Saved settings")
        } catch {
            print("❌ Failed to save settings: \(error.localizedDescription)")
        }
    }

    // MARK: - Public Methods

    func resetToDefaults() {
        settings = AppSettings.default
        print("🔄 Reset to default settings")
    }

    func applySettings() {
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        print("📢 Settings applied")
    }

    // Batch update to avoid multiple notifications
    func batchUpdate(_ updateBlock: (inout AppSettings) -> Void) {
        print("🔄 Starting batch update...")
        var newSettings = settings
        updateBlock(&newSettings)
        newSettings.validate()

        // Directly update without triggering didSet multiple times
        // We'll manually save and notify once at the end
        self.settings = newSettings
        print("✅ Batch update completed")
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let settingsDidChange = Notification.Name("settingsDidChange")
}
