//
//  HotkeyManager.swift
//  Quick Panel
//
//  Created by benxin on 2026/03/08.
//

import Cocoa
import Carbon
import Combine

class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    @Published var isEnabled: Bool = false
    @Published var currentKeyCode: UInt32 = 49       // Space
    @Published var currentModifiers: UInt32 = 0x0D00  // Cmd+Shift

    private init() {
        let settings = SettingsManager.shared.settings
        isEnabled = settings.hotkeyEnabled
        currentKeyCode = settings.hotkeyKeyCode
        currentModifiers = settings.hotkeyModifiers
    }

    // MARK: - Public API

    func updateHotkey(keyCode: UInt32, modifiers: UInt32, enabled: Bool) {
        currentKeyCode = keyCode
        currentModifiers = modifiers
        isEnabled = enabled

        var settings = SettingsManager.shared.settings
        settings.hotkeyKeyCode = keyCode
        settings.hotkeyModifiers = modifiers
        settings.hotkeyEnabled = enabled
        SettingsManager.shared.settings = settings

        print("⌨️ Hotkey updated: \(HotkeyManager.displayString(keyCode: keyCode, modifiers: modifiers)), enabled=\(enabled)")
    }

    // MARK: - Display Helpers

    static func displayString(keyCode: UInt32, modifiers: UInt32) -> String {
        var parts: [String] = []

        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }

        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }

    static func keyCodeToString(_ keyCode: UInt32) -> String {
        let keyMap: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space",
            50: "`", 51: "⌫", 53: "⎋", 96: "F5", 97: "F6", 98: "F7",
            99: "F3", 100: "F8", 101: "F9", 109: "F10", 103: "F11",
            111: "F12", 105: "F13", 107: "F14", 113: "F15",
            118: "F4", 120: "F2", 122: "F1", 123: "←", 124: "→",
            125: "↓", 126: "↑",
        ]
        return keyMap[keyCode] ?? "Key\(keyCode)"
    }

    static func nsModifiersToCarbon(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        return carbon
    }
}
