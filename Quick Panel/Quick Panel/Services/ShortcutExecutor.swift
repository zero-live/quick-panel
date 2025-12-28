//
//  ShortcutExecutor.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Cocoa

class ShortcutExecutor {
    static let shared = ShortcutExecutor()

    private init() {}

    func executeAction(_ action: ContextAction) {
        switch action.actionType {
        case .shortcut:
            executeKeyboardShortcut(action.actionData)
        case .applescript:
            executeAppleScript(action.actionData)
        case .shellCommand:
            executeShellCommand(action.actionData)
        }
    }

    // MARK: - Keyboard Shortcut Execution

    private func executeKeyboardShortcut(_ shortcutString: String) {
        print("⌨️ Executing keyboard shortcut: \(shortcutString)")

        guard let (modifiers, keyCode) = parseShortcut(shortcutString) else {
            print("❌ Failed to parse shortcut: \(shortcutString)")
            return
        }

        // Post keyboard events
        let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)

        keyDownEvent?.flags = modifiers
        keyUpEvent?.flags = modifiers

        keyDownEvent?.post(tap: .cghidEventTap)
        keyUpEvent?.post(tap: .cghidEventTap)

        print("✅ Shortcut executed successfully")
    }

    private func parseShortcut(_ shortcut: String) -> (CGEventFlags, CGKeyCode)? {
        let components = shortcut.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }

        var modifiers: CGEventFlags = []
        var key: String?

        for component in components {
            switch component.lowercased() {
            case "cmd", "command":
                modifiers.insert(.maskCommand)
            case "shift":
                modifiers.insert(.maskShift)
            case "option", "alt":
                modifiers.insert(.maskAlternate)
            case "ctrl", "control":
                modifiers.insert(.maskControl)
            default:
                key = component
            }
        }

        guard let key = key, let keyCode = keyCodeForString(key) else {
            return nil
        }

        return (modifiers, keyCode)
    }

    private func keyCodeForString(_ key: String) -> CGKeyCode? {
        let keyMap: [String: CGKeyCode] = [
            // Letters
            "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02, "e": 0x0E,
            "f": 0x03, "g": 0x05, "h": 0x04, "i": 0x22, "j": 0x26,
            "k": 0x28, "l": 0x25, "m": 0x2E, "n": 0x2D, "o": 0x1F,
            "p": 0x23, "q": 0x0C, "r": 0x0F, "s": 0x01, "t": 0x11,
            "u": 0x20, "v": 0x09, "w": 0x0D, "x": 0x07, "y": 0x10,
            "z": 0x06,

            // Numbers
            "0": 0x1D, "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15,
            "5": 0x17, "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19,

            // Function keys
            "f1": 0x7A, "f2": 0x78, "f3": 0x63, "f4": 0x76, "f5": 0x60,
            "f6": 0x61, "f7": 0x62, "f8": 0x64, "f9": 0x65, "f10": 0x6D,
            "f11": 0x67, "f12": 0x6F,

            // Special keys
            "space": 0x31, "return": 0x24, "enter": 0x24, "tab": 0x30,
            "delete": 0x33, "escape": 0x35, "esc": 0x35,

            // Punctuation
            ".": 0x2F, ",": 0x2B, "/": 0x2C, ";": 0x29, "'": 0x27,
            "[": 0x21, "]": 0x1E, "\\": 0x2A, "-": 0x1B, "=": 0x18,
            "`": 0x32,

            // Arrows
            "left": 0x7B, "right": 0x7C, "up": 0x7E, "down": 0x7D
        ]

        return keyMap[key.lowercased()]
    }

    // MARK: - AppleScript Execution

    private func executeAppleScript(_ script: String) {
        print("📜 Executing AppleScript")

        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?

        appleScript?.executeAndReturnError(&error)

        if let error = error {
            print("❌ AppleScript error: \(error)")
        } else {
            print("✅ AppleScript executed successfully")
        }
    }

    // MARK: - Shell Command Execution

    private func executeShellCommand(_ command: String) {
        print("🖥️ Executing shell command: \(command)")

        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", command]

        do {
            try task.run()
            task.waitUntilExit()
            print("✅ Shell command executed successfully")
        } catch {
            print("❌ Shell command error: \(error)")
        }
    }
}
