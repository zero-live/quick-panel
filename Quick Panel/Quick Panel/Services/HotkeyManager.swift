//
//  HotkeyManager.swift
//  Quick Panel
//
//  Created by benxin on 2026/03/08.
//

import Cocoa
import Carbon
import Combine

// Carbon 事件回调必须是全局 C 函数，不能是闭包或方法
private func carbonHotkeyCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event = event else { return OSStatus(eventNotHandledErr) }

    var hotkeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotkeyID
    )

    guard status == noErr else { return OSStatus(eventNotHandledErr) }

    // 0x5150 = "QP" 签名
    if hotkeyID.signature == 0x5150 && hotkeyID.id == 1 {
        DispatchQueue.main.async { @MainActor in
            let location = NSEvent.mouseLocation
            PanelWindowManager.shared.togglePanel(at: location)
        }
        return noErr
    }

    return OSStatus(eventNotHandledErr)
}

class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    @Published var isEnabled: Bool = false
    @Published var currentKeyCode: UInt32 = 49       // Space
    @Published var currentModifiers: UInt32 = 0x0D00  // Cmd+Shift

    private var hotkeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let logCategory: AppLogCategory = .app

    private init() {
        let settings = SettingsManager.shared.settings
        isEnabled = settings.hotkeyEnabled
        currentKeyCode = settings.hotkeyKeyCode
        currentModifiers = settings.hotkeyModifiers
    }

    // MARK: - Public API

    func start() {
        guard isEnabled else {
            AppLogger.debug("全局快捷键未启用，跳过启动。", category: logCategory)
            return
        }
        AppLogger.info("开始启动全局快捷键监听。", category: logCategory)
        installEventHandler()
        registerHotkey()
    }

    func stop() {
        unregisterHotkey()
        removeEventHandler()
        AppLogger.info("全局快捷键监听已停止。", category: logCategory)
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
            if eventHandlerRef == nil {
                installEventHandler()
            }
            registerHotkey()
        } else {
            removeEventHandler()
        }
        AppLogger.notice("全局快捷键已更新：\(HotkeyManager.displayString(keyCode: keyCode, modifiers: modifiers))，enabled=\(enabled)。", category: logCategory)
    }

    // MARK: - Carbon Event Handler

    private func installEventHandler() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            carbonHotkeyCallback,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        if status == noErr {
            AppLogger.debug("Carbon 快捷键事件处理器安装成功。", category: logCategory)
        } else {
            AppLogger.error("安装 Carbon 快捷键事件处理器失败，status=\(status)。", category: logCategory)
        }
    }

    private func removeEventHandler() {
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
            AppLogger.debug("Carbon 快捷键事件处理器已移除。", category: logCategory)
        }
    }

    private func registerHotkey() {
        unregisterHotkey()

        let carbonMods = carbonModifierFlags(from: currentModifiers)
        let hotkeyID = EventHotKeyID(signature: 0x5150, id: 1) // "QP"

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            currentKeyCode,
            carbonMods,
            hotkeyID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )

        if status == noErr {
            hotkeyRef = ref
        } else {
            AppLogger.error("注册全局快捷键失败，status=\(status)。", category: logCategory)
        }
    }

    private func unregisterHotkey() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
            AppLogger.debug("全局快捷键已注销。", category: logCategory)
        }
    }

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
        stop()
    }
}
