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
    var upperGridColumns: Int = 4   // 3-5
    var upperGridRows: Int = 3      // 3-5
    var lowerGridColumns: Int = 4   // 3-5
    var lowerGridRows: Int = 3      // 3-5
    var itemSpacing: CGFloat = 16   // 8-24
    var cellWidth: CGFloat = 70     // 50-100
    var cellHeight: CGFloat = 90    // 60-120
    var panelOpacity: Double = 1.0  // 0.5-1.0
    var launchAtLogin: Bool = false
    var hotkeyEnabled: Bool = false
    var hotkeyKeyCode: UInt32 = 49       // Default: Space (keyCode 49)
    var hotkeyModifiers: UInt32 = 0x0D00 // Default: Cmd+Shift (cmdKey | shiftKey)
    var autoCheckForUpdates: Bool = true
    var skippedUpdateVersion: String? = nil
    var lastUpdateCheckAt: Date? = nil

    // Computed properties
    var upperItemsPerPage: Int {
        upperGridColumns * upperGridRows
    }

    var lowerItemsPerPage: Int {
        lowerGridColumns * lowerGridRows
    }

    func itemsPerPage(for layer: PanelLayer) -> Int {
        layer == .upper ? upperItemsPerPage : lowerItemsPerPage
    }

    func gridColumns(for layer: PanelLayer) -> Int {
        layer == .upper ? upperGridColumns : lowerGridColumns
    }

    func gridRows(for layer: PanelLayer) -> Int {
        layer == .upper ? upperGridRows : lowerGridRows
    }

    var panelWidth: CGFloat {
        let maxCols = max(upperGridColumns, lowerGridColumns)
        return CGFloat(maxCols) * cellWidth + CGFloat(maxCols - 1) * itemSpacing + 40
    }

    func layerHeight(for layer: PanelLayer) -> CGFloat {
        let rows = gridRows(for: layer)
        return CGFloat(rows) * cellHeight + CGFloat(rows - 1) * itemSpacing + 48
    }

    // Validation
    mutating func validate() {
        upperGridColumns = max(3, min(5, upperGridColumns))
        upperGridRows = max(3, min(5, upperGridRows))
        lowerGridColumns = max(3, min(5, lowerGridColumns))
        lowerGridRows = max(3, min(5, lowerGridRows))
        itemSpacing = max(8, min(24, itemSpacing))
        cellWidth = max(50, min(100, cellWidth))
        cellHeight = max(60, min(120, cellHeight))
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

    }

    // MARK: - Load/Save

    private func loadSettings() {
        guard FileManager.default.fileExists(atPath: settingsFile.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: settingsFile)
            var loadedSettings = try JSONDecoder().decode(AppSettings.self, from: data)
            loadedSettings.validate()
            settings = loadedSettings
        } catch {
        }
    }

    private func saveSettings() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try data.write(to: settingsFile)
        } catch {
        }
    }

    // MARK: - Public Methods

    func resetToDefaults() {
        settings = AppSettings.default
    }

    func applySettings() {
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }

    // Batch update to avoid multiple notifications
    func batchUpdate(_ updateBlock: (inout AppSettings) -> Void) {
        var newSettings = settings
        updateBlock(&newSettings)
        newSettings.validate()

        // Directly update without triggering didSet multiple times
        // We'll manually save and notify once at the end
        self.settings = newSettings
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let settingsDidChange = Notification.Name("settingsDidChange")
}
