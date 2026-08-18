//
//  SettingsManager.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Foundation
import Combine
import AppKit

// MARK: - Panel Material Style

enum PanelMaterialStyle: String, Codable, CaseIterable, Identifiable {
    case liquidGlass         // NSGlassEffectView .regular — same material as the Dock / Control Center
    case liquidGlassClear    // NSGlassEffectView .clear — more transparent, more background color bleeding through
    case sidebar
    case popover
    case menu
    case hudWindow
    case contentBackground

    var id: String { rawValue }

    /// Whether this style renders via the macOS 26 `NSGlassEffectView` (true Liquid Glass)
    /// rather than the older `NSVisualEffectView` frosted-blur material.
    var usesLiquidGlass: Bool {
        self == .liquidGlass || self == .liquidGlassClear
    }

    var glassStyle: NSGlassEffectView.Style {
        self == .liquidGlassClear ? .clear : .regular
    }

    var material: NSVisualEffectView.Material {
        switch self {
        case .liquidGlass, .liquidGlassClear, .sidebar: return .sidebar
        case .popover: return .popover
        case .menu: return .menu
        case .hudWindow: return .hudWindow
        case .contentBackground: return .contentBackground
        }
    }

    var displayName: String {
        switch self {
        case .liquidGlass: return "液态玻璃（推荐，与 Dock 一致）"
        case .liquidGlassClear: return "液态玻璃 · 清透"
        case .sidebar: return "侧边栏"
        case .popover: return "弹出层"
        case .menu: return "菜单"
        case .hudWindow: return "HUD 深色"
        case .contentBackground: return "内容背景"
        }
    }
}

// MARK: - AppSettings Model

struct AppSettings: Codable, Equatable {
    static let layerHeaderHeight: CGFloat = 34
    static let layerGridBottomPadding: CGFloat = 8
    static let layerPageIndicatorHeight: CGFloat = 14
    static let layerBaseVerticalPadding: CGFloat = 8

    var upperGridColumns: Int = 4   // 3-5
    var upperGridRows: Int = 3      // 3-5
    var lowerGridColumns: Int = 4   // 3-5
    var lowerGridRows: Int = 3      // 3-5
    var itemSpacing: CGFloat = 16   // 8-24
    var cellWidth: CGFloat = 70     // 50-100
    var cellHeight: CGFloat = 90    // 60-120
    var panelOpacity: Double = 1.0  // 0.2-1.0, applied to the glass background only
    var panelMaterialStyle: PanelMaterialStyle = .liquidGlass
    var launchAtLogin: Bool = false
    var hotkeyEnabled: Bool = false
    var hotkeyKeyCode: UInt32 = 49       // Default: Space (keyCode 49)
    var hotkeyModifiers: UInt32 = 0x0D00 // Default: Cmd+Shift (cmdKey | shiftKey)
    var autoCheckForUpdates: Bool = true
    var skippedUpdateVersion: String? = nil
    var lastUpdateCheckAt: Date? = nil
    var lowerPageMemory: [String: Int] = [:]

    init() {}

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
        let gridHeight = CGFloat(rows) * cellHeight + CGFloat(rows - 1) * itemSpacing
        return AppSettings.layerHeaderHeight
            + AppSettings.layerBaseVerticalPadding
            + gridHeight
            + AppSettings.layerGridBottomPadding
            + AppSettings.layerPageIndicatorHeight
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
        panelOpacity = max(0.2, min(1.0, panelOpacity))
        lowerPageMemory = lowerPageMemory.reduce(into: [:]) { partialResult, entry in
            partialResult[entry.key] = max(0, entry.value)
        }
    }

    static var `default`: AppSettings {
        return AppSettings()
    }

    // Settings files are user data that outlive app versions. Decode missing
    // keys from their defaults instead of rejecting the complete file.
    private enum CodingKeys: String, CodingKey {
        case upperGridColumns, upperGridRows, lowerGridColumns, lowerGridRows
        case itemSpacing, cellWidth, cellHeight, panelOpacity, panelMaterialStyle
        case launchAtLogin, hotkeyEnabled, hotkeyKeyCode, hotkeyModifiers
        case autoCheckForUpdates, skippedUpdateVersion, lastUpdateCheckAt, lowerPageMemory
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init()

        upperGridColumns = try container.decodeIfPresent(Int.self, forKey: .upperGridColumns) ?? upperGridColumns
        upperGridRows = try container.decodeIfPresent(Int.self, forKey: .upperGridRows) ?? upperGridRows
        lowerGridColumns = try container.decodeIfPresent(Int.self, forKey: .lowerGridColumns) ?? lowerGridColumns
        lowerGridRows = try container.decodeIfPresent(Int.self, forKey: .lowerGridRows) ?? lowerGridRows
        itemSpacing = try container.decodeIfPresent(CGFloat.self, forKey: .itemSpacing) ?? itemSpacing
        cellWidth = try container.decodeIfPresent(CGFloat.self, forKey: .cellWidth) ?? cellWidth
        cellHeight = try container.decodeIfPresent(CGFloat.self, forKey: .cellHeight) ?? cellHeight
        panelOpacity = try container.decodeIfPresent(Double.self, forKey: .panelOpacity) ?? panelOpacity
        panelMaterialStyle = try container.decodeIfPresent(PanelMaterialStyle.self, forKey: .panelMaterialStyle) ?? panelMaterialStyle
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? launchAtLogin
        hotkeyEnabled = try container.decodeIfPresent(Bool.self, forKey: .hotkeyEnabled) ?? hotkeyEnabled
        hotkeyKeyCode = try container.decodeIfPresent(UInt32.self, forKey: .hotkeyKeyCode) ?? hotkeyKeyCode
        hotkeyModifiers = try container.decodeIfPresent(UInt32.self, forKey: .hotkeyModifiers) ?? hotkeyModifiers
        autoCheckForUpdates = try container.decodeIfPresent(Bool.self, forKey: .autoCheckForUpdates) ?? autoCheckForUpdates
        skippedUpdateVersion = try container.decodeIfPresent(String.self, forKey: .skippedUpdateVersion)
        lastUpdateCheckAt = try container.decodeIfPresent(Date.self, forKey: .lastUpdateCheckAt)
        lowerPageMemory = try container.decodeIfPresent([String: Int].self, forKey: .lowerPageMemory) ?? lowerPageMemory
    }
}

// MARK: - SettingsManager

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var settings: AppSettings {
        didSet {
            guard !isLoadingSettings else { return }
            var validatedSettings = settings
            validatedSettings.validate()
            if validatedSettings != settings {
                settings = validatedSettings
                return
            }
            saveSettings()
            if !isSuppressingSettingsDidChange {
                NotificationCenter.default.post(name: .settingsDidChange, object: nil)
            }
        }
    }

    private let configDirectory: URL
    private let settingsFile: URL
    private var isSuppressingSettingsDidChange = false
    private var isLoadingSettings = false

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
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: settingsFile.path) else { return }

        let backupURL = settingsFile.appendingPathExtension("backup")
        for candidateURL in [settingsFile, backupURL] where fileManager.fileExists(atPath: candidateURL.path) {
            do {
                let data = try Data(contentsOf: candidateURL)
                var loadedSettings = try JSONDecoder().decode(AppSettings.self, from: data)
                loadedSettings.validate()

                if candidateURL == backupURL {
                    archiveCorruptSettingsFile()
                    try data.write(to: settingsFile, options: .atomic)
                    AppLogger.notice("设置已从备份恢复。", category: .data)
                }

                isLoadingSettings = true
                settings = loadedSettings
                isLoadingSettings = false
                return
            } catch {
                AppLogger.error("读取设置失败（\(candidateURL.lastPathComponent)）：\(error.localizedDescription)", category: .data)
            }
        }

        archiveCorruptSettingsFile()
        AppLogger.error("设置无法恢复，已使用默认设置启动。", category: .data)
    }

    private func saveSettings() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try writeSettingsAtomically(data)
        } catch {
            AppLogger.error("保存设置失败：\(error.localizedDescription)", category: .data)
        }
    }

    private func writeSettingsAtomically(_ data: Data) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: settingsFile.path) {
            let currentData = try Data(contentsOf: settingsFile)
            try currentData.write(to: settingsFile.appendingPathExtension("backup"), options: .atomic)
        }
        try data.write(to: settingsFile, options: .atomic)
    }

    private func archiveCorruptSettingsFile() {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: settingsFile.path) else { return }

        let timestamp = Int(Date().timeIntervalSince1970)
        let archiveURL = settingsFile.deletingLastPathComponent().appendingPathComponent(
            "\(settingsFile.lastPathComponent).corrupt-\(timestamp)"
        )
        do {
            try fileManager.copyItem(at: settingsFile, to: archiveURL)
            AppLogger.notice("已保留无法读取的设置副本：\(archiveURL.lastPathComponent)。", category: .data)
        } catch {
            AppLogger.error("保留异常设置副本失败：\(error.localizedDescription)", category: .data)
        }
    }

    // MARK: - Public Methods

    func resetToDefaults() {
        HotkeyManager.shared.updateHotkey(
            keyCode: AppSettings.default.hotkeyKeyCode,
            modifiers: AppSettings.default.hotkeyModifiers,
            enabled: false
        )
        _ = LoginItemManager.shared.setLaunchAtLogin(false)
        settings = AppSettings.default
    }

    func applySettings() {
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }

    func persistLowerPageMemory(_ memory: [String: Int]) {
        var newSettings = settings
        newSettings.lowerPageMemory = memory
        newSettings.validate()

        guard newSettings != settings else { return }

        isSuppressingSettingsDidChange = true
        settings = newSettings
        isSuppressingSettingsDidChange = false
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
