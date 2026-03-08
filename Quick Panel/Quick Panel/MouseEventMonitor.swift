//
//  MouseEventMonitor.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Cocoa
import Carbon

class MouseEventMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMouseMonitor: Any?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private let middleClickCallback: (CGPoint) -> Void
    private var useBackupMethod = false

    init(callback: @escaping (CGPoint) -> Void) {
        self.middleClickCallback = callback
    }

    func start() {
        guard eventTap == nil && globalMouseMonitor == nil else {
            print("⚠️ Event monitor already exists")
            return
        }

        print("🖱️ Starting event monitor...")

        if startCGEventMonitor() {
            print("✅ Using CGEvent monitor (mouse + keyboard)")
            useBackupMethod = false
            return
        }

        print("⚠️ CGEvent failed, trying NSEvent backup method...")
        startNSEventMonitors()
        useBackupMethod = true
    }

    // MARK: - CGEvent Tap (Primary — single tap for mouse + keyboard)

    private func startCGEventMonitor() -> Bool {
        let eventMask = (1 << CGEventType.otherMouseDown.rawValue) |
                        (1 << CGEventType.keyDown.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<MouseEventMonitor>.fromOpaque(refcon).takeUnretainedValue()

                switch type {
                case .otherMouseDown:
                    let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
                    if buttonNumber == 2 {
                        let location = NSEvent.mouseLocation
                        print("✨ Middle button clicked at: \(location)")
                        DispatchQueue.main.async {
                            monitor.middleClickCallback(location)
                        }
                    }

                case .keyDown:
                    let hotkeyManager = HotkeyManager.shared
                    guard hotkeyManager.isEnabled else { break }

                    let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
                    let flags = event.flags
                    var carbonMods: UInt32 = 0
                    if flags.contains(.maskCommand) { carbonMods |= UInt32(cmdKey) }
                    if flags.contains(.maskShift) { carbonMods |= UInt32(shiftKey) }
                    if flags.contains(.maskAlternate) { carbonMods |= UInt32(optionKey) }
                    if flags.contains(.maskControl) { carbonMods |= UInt32(controlKey) }

                    if keyCode == hotkeyManager.currentKeyCode && carbonMods == hotkeyManager.currentModifiers {
                        print("⌨️ Global hotkey matched: \(HotkeyManager.displayString(keyCode: keyCode, modifiers: carbonMods))")
                        DispatchQueue.main.async {
                            let location = NSEvent.mouseLocation
                            PanelWindowManager.shared?.togglePanel(at: location)
                        }
                    }

                case .tapDisabledByTimeout, .tapDisabledByUserInput:
                    if let tap = monitor.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                        print("🔄 Re-enabled event tap after system disabled it")
                    }

                default:
                    break
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("❌ Failed to create CGEvent tap")
            return false
        }

        self.eventTap = eventTap

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        self.runLoopSource = runLoopSource

        return true
    }

    // MARK: - NSEvent Fallback (mouse + keyboard via separate monitors)

    private func startNSEventMonitors() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.otherMouseDown]) { [weak self] event in
            guard let self = self else { return }
            if event.buttonNumber == 2 {
                let location = NSEvent.mouseLocation
                print("✨ Middle button clicked (NSEvent) at: \(location)")
                DispatchQueue.main.async {
                    self.middleClickCallback(location)
                }
            }
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
            let hotkeyManager = HotkeyManager.shared
            guard hotkeyManager.isEnabled else { return }

            let eventMods = HotkeyManager.nsModifiersToCarbon(event.modifierFlags.intersection(.deviceIndependentFlagsMask))
            if UInt32(event.keyCode) == hotkeyManager.currentKeyCode && eventMods == hotkeyManager.currentModifiers {
                print("⌨️ Global hotkey matched (NSEvent): \(HotkeyManager.displayString(keyCode: UInt32(event.keyCode), modifiers: eventMods))")
                DispatchQueue.main.async {
                    let location = NSEvent.mouseLocation
                    PanelWindowManager.shared?.togglePanel(at: location)
                }
            }
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            let hotkeyManager = HotkeyManager.shared
            guard hotkeyManager.isEnabled else { return event }

            let eventMods = HotkeyManager.nsModifiersToCarbon(event.modifierFlags.intersection(.deviceIndependentFlagsMask))
            if UInt32(event.keyCode) == hotkeyManager.currentKeyCode && eventMods == hotkeyManager.currentModifiers {
                print("⌨️ Global hotkey matched (local NSEvent)")
                DispatchQueue.main.async {
                    let location = NSEvent.mouseLocation
                    PanelWindowManager.shared?.togglePanel(at: location)
                }
                return nil
            }
            return event
        }

        if globalMouseMonitor != nil {
            print("✅ NSEvent monitors started (backup method)")
        } else {
            print("❌ Failed to start NSEvent monitors")
        }
    }

    func stop() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            if let runLoopSource = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            }
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
            self.runLoopSource = nil
        }

        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }

        print("Event monitors stopped")
    }

    func isUsingBackupMethod() -> Bool {
        return useBackupMethod
    }

    deinit {
        stop()
    }
}
