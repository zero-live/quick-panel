//
//  ContextAction.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Foundation

// MARK: - Context Action Model

struct ContextAction: Identifiable, Codable {
    let id: UUID
    let name: String
    let icon: String  // SF Symbol name
    let actionType: ActionType
    let actionData: String  // Shortcut combination or AppleScript

    init(id: UUID = UUID(), name: String, icon: String, actionType: ActionType, actionData: String) {
        self.id = id
        self.name = name
        self.icon = icon
        self.actionType = actionType
        self.actionData = actionData
    }
}

enum ActionType: String, Codable {
    case shortcut       // Keyboard shortcut (e.g., "Cmd+T")
    case applescript    // AppleScript code
    case shellCommand   // Shell command
}

// MARK: - App Preset Model

struct AppPreset: Codable {
    let bundleIdentifier: String
    let appName: String
    let actions: [ContextAction]
}

// MARK: - Preset Configuration

class PresetConfiguration {
    static let shared = PresetConfiguration()

    private init() {}

    // Predefined presets for common applications
    let presets: [String: AppPreset] = [
        // Chrome
        "com.google.Chrome": AppPreset(
            bundleIdentifier: "com.google.Chrome",
            appName: "Google Chrome",
            actions: [
                ContextAction(name: "新标签页", icon: "plus.square", actionType: .shortcut, actionData: "Cmd+T"),
                ContextAction(name: "隐私窗口", icon: "eye.slash", actionType: .shortcut, actionData: "Cmd+Shift+N"),
                ContextAction(name: "关闭标签", icon: "xmark", actionType: .shortcut, actionData: "Cmd+W"),
                ContextAction(name: "重新打开", icon: "arrow.counterclockwise", actionType: .shortcut, actionData: "Cmd+Shift+T"),
                ContextAction(name: "刷新页面", icon: "arrow.clockwise", actionType: .shortcut, actionData: "Cmd+R"),
                ContextAction(name: "查找", icon: "magnifyingglass", actionType: .shortcut, actionData: "Cmd+F"),
                ContextAction(name: "书签栏", icon: "bookmark", actionType: .shortcut, actionData: "Cmd+Shift+B"),
                ContextAction(name: "历史记录", icon: "clock", actionType: .shortcut, actionData: "Cmd+Y")
            ]
        ),

        // Safari
        "com.apple.Safari": AppPreset(
            bundleIdentifier: "com.apple.Safari",
            appName: "Safari",
            actions: [
                ContextAction(name: "新标签页", icon: "plus.square", actionType: .shortcut, actionData: "Cmd+T"),
                ContextAction(name: "隐私窗口", icon: "eye.slash", actionType: .shortcut, actionData: "Cmd+Shift+N"),
                ContextAction(name: "关闭标签", icon: "xmark", actionType: .shortcut, actionData: "Cmd+W"),
                ContextAction(name: "重新打开", icon: "arrow.counterclockwise", actionType: .shortcut, actionData: "Cmd+Z"),
                ContextAction(name: "刷新页面", icon: "arrow.clockwise", actionType: .shortcut, actionData: "Cmd+R"),
                ContextAction(name: "查找", icon: "magnifyingglass", actionType: .shortcut, actionData: "Cmd+F"),
                ContextAction(name: "书签", icon: "bookmark", actionType: .shortcut, actionData: "Cmd+Shift+B"),
                ContextAction(name: "阅读列表", icon: "list.bullet", actionType: .shortcut, actionData: "Cmd+Shift+L")
            ]
        ),

        // Finder
        "com.apple.finder": AppPreset(
            bundleIdentifier: "com.apple.finder",
            appName: "Finder",
            actions: [
                ContextAction(name: "新建窗口", icon: "plus.rectangle", actionType: .shortcut, actionData: "Cmd+N"),
                ContextAction(name: "新建文件夹", icon: "folder.badge.plus", actionType: .shortcut, actionData: "Cmd+Shift+N"),
                ContextAction(name: "显示隐藏", icon: "eye", actionType: .shortcut, actionData: "Cmd+Shift+."),
                ContextAction(name: "前往文件夹", icon: "arrow.right.square", actionType: .shortcut, actionData: "Cmd+Shift+G"),
                ContextAction(name: "应用程序", icon: "app", actionType: .shortcut, actionData: "Cmd+Shift+A"),
                ContextAction(name: "下载", icon: "arrow.down.doc", actionType: .shortcut, actionData: "Cmd+Option+L"),
                ContextAction(name: "桌面", icon: "desktopcomputer", actionType: .shortcut, actionData: "Cmd+Shift+D"),
                ContextAction(name: "主目录", icon: "house", actionType: .shortcut, actionData: "Cmd+Shift+H")
            ]
        ),

        // Visual Studio Code
        "com.microsoft.VSCode": AppPreset(
            bundleIdentifier: "com.microsoft.VSCode",
            appName: "Visual Studio Code",
            actions: [
                ContextAction(name: "命令面板", icon: "command", actionType: .shortcut, actionData: "Cmd+Shift+P"),
                ContextAction(name: "新建文件", icon: "doc.badge.plus", actionType: .shortcut, actionData: "Cmd+N"),
                ContextAction(name: "保存", icon: "square.and.arrow.down", actionType: .shortcut, actionData: "Cmd+S"),
                ContextAction(name: "格式化", icon: "text.alignleft", actionType: .shortcut, actionData: "Shift+Option+F"),
                ContextAction(name: "查找", icon: "magnifyingglass", actionType: .shortcut, actionData: "Cmd+F"),
                ContextAction(name: "替换", icon: "arrow.left.arrow.right", actionType: .shortcut, actionData: "Cmd+Option+F"),
                ContextAction(name: "终端", icon: "terminal", actionType: .shortcut, actionData: "Ctrl+`"),
                ContextAction(name: "侧边栏", icon: "sidebar.left", actionType: .shortcut, actionData: "Cmd+B")
            ]
        ),

        // Xcode
        "com.apple.dt.Xcode": AppPreset(
            bundleIdentifier: "com.apple.dt.Xcode",
            appName: "Xcode",
            actions: [
                ContextAction(name: "运行", icon: "play.fill", actionType: .shortcut, actionData: "Cmd+R"),
                ContextAction(name: "停止", icon: "stop.fill", actionType: .shortcut, actionData: "Cmd+."),
                ContextAction(name: "构建", icon: "hammer.fill", actionType: .shortcut, actionData: "Cmd+B"),
                ContextAction(name: "清理", icon: "trash", actionType: .shortcut, actionData: "Cmd+Shift+K"),
                ContextAction(name: "查找", icon: "magnifyingglass", actionType: .shortcut, actionData: "Cmd+Shift+F"),
                ContextAction(name: "快速打开", icon: "doc.text.magnifyingglass", actionType: .shortcut, actionData: "Cmd+Shift+O"),
                ContextAction(name: "导航器", icon: "sidebar.left", actionType: .shortcut, actionData: "Cmd+0"),
                ContextAction(name: "调试器", icon: "ant", actionType: .shortcut, actionData: "Cmd+Shift+Y")
            ]
        )
    ]

    func getPreset(for bundleIdentifier: String) -> AppPreset? {
        return presets[bundleIdentifier]
    }
}
