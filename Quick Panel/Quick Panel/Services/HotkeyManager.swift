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
    @Published var currentKeyCode: UInt32 = 49
    @Published var currentModifiers: UInt32 = 0x0D00

    private var hotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private static let hotkeyID = EventHotKeyID(
        signature: OSType(0x5150_4B59), // "QPKY"
        id: 1
    )

    private init() {
        let settings = SettingsManager.shared.settings
        isEnabled = settings.hotkeyEnabled
        currentKeyCode = settings.hotkeyKeyCode
        currentModifiers = settings.hotkeyModifiers

        NotificationCenter.default.addObserver(
            forName: .hotkeySettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadFromSettings()
        }
    }

    // MARK: - Public API

    func start() {
        guard isEnabled else {
            print("⌨️ Global hotkey disabled, skipping registration")
            return
        }
        registerHotkey()
    }

    func stop() {
        unregisterHotkey()
    }

    func updateHotkey(keyCode: UInt32, modifiers: UInt32, enabled: Bool) {
        unregisterHotkey()

        currentKeyCode = keyCode
        currentModifiers = modifiers
        isEnabled = enabled

        var settings = SettingsManager.shared.settings
        settings.hotkeyKeyCode = keyCode
        settings.hotkeyModifiers = modifiers
        settings.hotkeyEnabled = enabled
        SettingsManager.shared.settings = settings

        if enabled {
            registerHotkey()
        }

        print("⌨️ Hotkey updated: keyCode=\(keyCode), modifiers=\(String(format: "0x%04X", modifiers)), enabled=\(enabled)")
    }

    // MARK: - Registration

    private func registerHotkey() {
        unregisterHotkey()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

                var hotkeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyID
                )

                if hotkeyID.id == HotkeyManager.hotkeyID.id {
                    DispatchQueue.main.async {
                        manager.handleHotkeyPressed()
                    }
                    return noErr
                }

                return OSStatus(eventNotHandledErr)
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )

        guard status == noErr else {
            print("❌ Failed to install event handler: \(status)")
            return
        }

        let carbonModifiers = carbonModifierFlags(from: currentModifiers)

        var hotkeyRef: EventHotKeyRef?
        var hotkeyID = HotkeyManager.hotkeyID
        let registerStatus = RegisterEventHotKey(
            currentKeyCode,
            carbonModifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        guard registerStatus == noErr else {
            print("❌ Failed to register hotkey: \(registerStatus)")
            return
        }

        self.hotkeyRef = hotkeyRef
        print("✅ Global hotkey registered: keyCode=\(currentKeyCode), modifiers=\(String(format: "0x%04X", currentModifiers))")
    }

    private func unregisterHotkey() {
        if let hotkeyRef = hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func handleHotkeyPressed() {
        print("⌨️ Global hotkey pressed!")
        let location = NSEvent.mouseLocation
        PanelWindowManager.shared?.togglePanel(at: location)
    }

    private func reloadFromSettings() {
        let settings = SettingsManager.shared.settings
        updateHotkey(
            keyCode: settings.hotkeyKeyCode,
            modifiers: settings.hotkeyModifiers,
            enabled: settings.hotkeyEnabled
        )
    }

    // MARK: - Modifier Conversion

    // The stored modifiers use Carbon format directly (cmdKey, shiftKey, etc.)
    // so this just passes through, but validates the mask
    private func carbonModifierFlags(from stored: UInt32) -> UInt32 {
        var result: UInt32 = 0
        if stored & UInt32(cmdKey) != 0 { result |= UInt32(cmdKey) }
        if stored & UInt32(shiftKey) != 0 { result |= UInt32(shiftKey) }
        if stored & UInt32(optionKey) != 0 { result |= UInt32(optionKey) }
        if stored & UInt32(controlKey) != 0 { result |= UInt32(controlKey) }
        return result
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

    deinit {
        unregisterHotkey()
    }
}
