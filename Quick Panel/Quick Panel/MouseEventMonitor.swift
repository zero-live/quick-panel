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
    private let logCategory: AppLogCategory = .app

    init(callback: @escaping (CGPoint) -> Void) {
        self.callback = callback
    }

    func start() {
        guard eventTap == nil && globalMonitor == nil else {
            AppLogger.debug("鼠标监听已启动，忽略重复 start。", category: logCategory)
            return
        }

        AppLogger.info("开始启动鼠标事件监听。", category: logCategory)

        if startCGEventMonitor() {
            useBackupMethod = false
            AppLogger.info("已启用 CGEvent 鼠标监听。", category: logCategory)
            return
        }

        startNSEventMonitor()
        useBackupMethod = true
        AppLogger.notice("CGEvent 监听不可用，已切换到 NSEvent 备用监听。", category: logCategory)
    }

    private func startCGEventMonitor() -> Bool {
        let eventMask = (1 << CGEventType.otherMouseDown.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }

                let monitor = Unmanaged<MouseEventMonitor>.fromOpaque(refcon).takeUnretainedValue()

                if type == .otherMouseDown {
                    let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
                    if buttonNumber == 2 {
                        let location = NSEvent.mouseLocation
                        DispatchQueue.main.async {
                            AppLogger.debug("收到中键点击事件。", category: monitor.logCategory)
                            monitor.callback(location)
                        }
                    }
                } else if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = monitor.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                        AppLogger.notice("CGEvent tap 被系统禁用后已重新启用。", category: monitor.logCategory)
                    }
                }

                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            AppLogger.error("创建 CGEvent tap 失败。", category: logCategory)
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

                DispatchQueue.main.async {
                    AppLogger.debug("收到备用 NSEvent 中键点击事件。", category: self.logCategory)
                    self.callback(location)
                }
            }
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
        AppLogger.info("鼠标事件监听已停止。", category: logCategory)
    }

    func isUsingBackupMethod() -> Bool {
        return useBackupMethod
    }

    deinit {
        stop()
    }
}
