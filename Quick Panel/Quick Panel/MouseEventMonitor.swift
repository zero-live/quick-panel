//
//  MouseEventMonitor.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Cocoa

class MouseEventMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private let callback: (CGPoint) -> Void
    private var useBackupMethod = false

    init(callback: @escaping (CGPoint) -> Void) {
        self.callback = callback
    }

    func start() {
        guard eventTap == nil && globalMonitor == nil else {
            print("⚠️ Event monitor already exists")
            return
        }

        print("🖱️ Starting mouse event monitor...")

        if startCGEventMonitor() {
            print("✅ Using CGEvent monitor (permission granted)")
            useBackupMethod = false
            return
        }

        print("⚠️ CGEvent failed, trying NSEvent backup method...")
        startNSEventMonitor()
        useBackupMethod = true
    }

    private func startCGEventMonitor() -> Bool {
        let eventMask = (1 << CGEventType.otherMouseDown.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }

                let monitor = Unmanaged<MouseEventMonitor>.fromOpaque(refcon).takeUnretainedValue()

                if type == .otherMouseDown {
                    let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
                    if buttonNumber == 2 {
                        let location = NSEvent.mouseLocation
                        print("✨ Middle button clicked at: \(location)")
                        DispatchQueue.main.async {
                            monitor.callback(location)
                        }
                    }
                } else if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = monitor.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                        print("🔄 Re-enabled event tap")
                    }
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

    private func startNSEventMonitor() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.otherMouseDown]) { [weak self] event in
            guard let self = self else { return }

            if event.buttonNumber == 2 {
                let location = NSEvent.mouseLocation
                print("✨ Middle button clicked (NSEvent) at: \(location)")

                DispatchQueue.main.async {
                    self.callback(location)
                }
            }
        }

        if globalMonitor != nil {
            print("✅ NSEvent monitor started (backup method)")
        } else {
            print("❌ Failed to start NSEvent monitor")
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

        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }

        print("Mouse event monitor stopped")
    }

    func isUsingBackupMethod() -> Bool {
        return useBackupMethod
    }

    deinit {
        stop()
    }
}
