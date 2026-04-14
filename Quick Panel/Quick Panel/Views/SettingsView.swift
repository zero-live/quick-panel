//
//  SettingsView.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    @ObservedObject var dataManager = DataManager.shared

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GridSettingsTab()
                .tabItem {
                    Label("网格", systemImage: "square.grid.3x3")
                }
                .tag(0)

            AppearanceTab()
                .tabItem {
                    Label("外观", systemImage: "paintbrush")
                }
                .tag(1)

            ItemManagementTab()
                .tabItem {
                    Label("管理", systemImage: "list.bullet")
                }
                .tag(2)

            AdvancedTab()
                .tabItem {
                    Label("高级", systemImage: "gearshape")
                }
                .tag(3)
        }
        .frame(width: 600, height: 500)
    }
}

// MARK: - Grid Settings Tab

struct GridSettingsTab: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    @State private var tempUpperColumns: Int = 4
    @State private var tempUpperRows: Int = 3
    @State private var tempLowerColumns: Int = 4
    @State private var tempLowerRows: Int = 3
    @State private var tempSpacing: Double = 16

    var previewUpperItemsPerPage: Int {
        tempUpperColumns * tempUpperRows
    }

    var previewLowerItemsPerPage: Int {
        tempLowerColumns * tempLowerRows
    }

    var previewPanelWidth: CGFloat {
        let maxCols = max(tempUpperColumns, tempLowerColumns)
        return CGFloat(maxCols) * 70 + CGFloat(maxCols - 1) * tempSpacing + 40
    }

    var previewUpperLayerHeight: CGFloat {
        CGFloat(tempUpperRows) * 90 + CGFloat(tempUpperRows - 1) * tempSpacing + 48
    }

    var previewLowerLayerHeight: CGFloat {
        CGFloat(tempLowerRows) * 90 + CGFloat(tempLowerRows - 1) * tempSpacing + 48
    }

    var hasChanges: Bool {
        tempUpperColumns != settingsManager.settings.upperGridColumns ||
        tempUpperRows != settingsManager.settings.upperGridRows ||
        tempLowerColumns != settingsManager.settings.lowerGridColumns ||
        tempLowerRows != settingsManager.settings.lowerGridRows ||
        tempSpacing != settingsManager.settings.itemSpacing
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content area with ScrollView
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Upper Layer Header
                    HStack {
                        Image(systemName: "square.grid.2x2")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("上层网格")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                    }

                    // Upper Columns
                    SettingRow(
                        icon: "square.split.2x1",
                        title: "列数",
                        subtitle: "每行显示的项目数量"
                    ) {
                        Stepper("\(tempUpperColumns)", value: $tempUpperColumns, in: 3...5)
                            .frame(width: 80)
                    }

                    Divider()

                    // Upper Rows
                    SettingRow(
                        icon: "square.split.1x2",
                        title: "行数",
                        subtitle: "每列显示的项目数量"
                    ) {
                        Stepper("\(tempUpperRows)", value: $tempUpperRows, in: 3...5)
                            .frame(width: 80)
                    }

                    Divider()

                    // Lower Layer Header
                    HStack {
                        Image(systemName: "square.grid.2x2")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        Text("下层网格")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                    }

                    // Lower Columns
                    SettingRow(
                        icon: "square.split.2x1",
                        title: "列数",
                        subtitle: "每行显示的项目数量"
                    ) {
                        Stepper("\(tempLowerColumns)", value: $tempLowerColumns, in: 3...5)
                            .frame(width: 80)
                    }

                    Divider()

                    // Lower Rows
                    SettingRow(
                        icon: "square.split.1x2",
                        title: "行数",
                        subtitle: "每列显示的项目数量"
                    ) {
                        Stepper("\(tempLowerRows)", value: $tempLowerRows, in: 3...5)
                            .frame(width: 80)
                    }

                    Divider()

                    // Spacing
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.left.and.right")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("间距")
                                    .font(.system(size: 13, weight: .medium))
                                Text("项目之间的间距")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(Int(tempSpacing)) pt")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .trailing)
                        }

                        Slider(value: $tempSpacing, in: 8...24, step: 1)
                            .padding(.leading, 32)
                    }

                    Divider()

                    // Preview
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "eye")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("预览")
                                .font(.system(size: 13, weight: .medium))
                        }

                        VStack(spacing: 8) {
                            PreviewRow(icon: "square.grid.3x3", label: "上层", value: "\(previewUpperItemsPerPage) 项 (\(tempUpperColumns)×\(tempUpperRows))")
                            PreviewRow(icon: "square.grid.3x3", label: "下层", value: "\(previewLowerItemsPerPage) 项 (\(tempLowerColumns)×\(tempLowerRows))")
                            PreviewRow(icon: "aspectratio", label: "宽度", value: "\(Int(previewPanelWidth)) pt")
                        }
                        .padding(.leading, 32)
                    }
                }
                .padding(24)
            }

            // Bottom action bar - always visible
            Divider()

            HStack(spacing: 12) {
                if hasChanges {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 14))
                        Text("有未保存的更改")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button("重置") {
                    loadCurrentSettings()
                }
                .buttonStyle(.bordered)
                .disabled(!hasChanges)

                Button("应用") {
                    applyChanges()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasChanges)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
        .onAppear {
            loadCurrentSettings()
        }
    }

    private func loadCurrentSettings() {
        tempUpperColumns = settingsManager.settings.upperGridColumns
        tempUpperRows = settingsManager.settings.upperGridRows
        tempLowerColumns = settingsManager.settings.lowerGridColumns
        tempLowerRows = settingsManager.settings.lowerGridRows
        tempSpacing = settingsManager.settings.itemSpacing
    }

    private func applyChanges() {
        settingsManager.batchUpdate { settings in
            settings.upperGridColumns = tempUpperColumns
            settings.upperGridRows = tempUpperRows
            settings.lowerGridColumns = tempLowerColumns
            settings.lowerGridRows = tempLowerRows
            settings.itemSpacing = tempSpacing
        }
    }
}

// MARK: - Appearance Tab

struct AppearanceTab: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    @State private var tempOpacity: Double = 1.0

    var hasChanges: Bool {
        tempOpacity != settingsManager.settings.panelOpacity
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content area with ScrollView
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Opacity
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "circle.lefthalf.filled")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("透明度")
                                    .font(.system(size: 13, weight: .medium))
                                Text("调整面板的不透明程度")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(Int(tempOpacity * 100))%")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .trailing)
                        }

                        Slider(value: $tempOpacity, in: 0.5...1.0, step: 0.05)
                            .padding(.leading, 32)
                    }

                    Divider()

                    // Preview
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "eye")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("预览")
                                .font(.system(size: 13, weight: .medium))
                        }

                        HStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .opacity(tempOpacity)
                                .frame(width: 240, height: 160)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "square.grid.3x3")
                                            .font(.system(size: 36))
                                            .foregroundColor(.blue)
                                        Text("\(Int(tempOpacity * 100))%")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                )
                                .shadow(radius: 8)
                            Spacer()
                        }
                        .padding(.leading, 32)
                    }
                }
                .padding(24)
            }

            // Bottom action bar - always visible
            Divider()

            HStack(spacing: 12) {
                if hasChanges {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 14))
                        Text("有未保存的更改")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button("重置") {
                    loadCurrentSettings()
                }
                .buttonStyle(.bordered)
                .disabled(!hasChanges)

                Button("应用") {
                    applyChanges()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasChanges)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
        .onAppear {
            loadCurrentSettings()
        }
    }

    private func loadCurrentSettings() {
        tempOpacity = settingsManager.settings.panelOpacity
    }

    private func applyChanges() {
        settingsManager.settings.panelOpacity = tempOpacity
    }
}

// MARK: - Item Management Tab

struct ItemManagementTab: View {
    @ObservedObject var dataManager = DataManager.shared

    var upperItems: [PanelItem] {
        dataManager.getItems(for: .upper)
    }

    var lowerItemsGrouped: [String: [PanelItem]] {
        let items = dataManager.items.filter { $0.layer == .lower }
        return Dictionary(grouping: items) { item in
            item.appBundleIdentifier ?? "未分组"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.3x3")
                        .foregroundColor(.blue)
                    Text("\(dataManager.items.count) 个项目")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: {
                        AddItemWindowManager.shared.showAddItemWindow(layer: .upper, appBundleId: nil, appName: nil)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "star")
                            Text("添加常用")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(action: {
                        AddItemWindowManager.shared.showAddItemWindow(layer: .lower, appBundleId: nil, appName: nil)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "app")
                            Text("添加下层")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            // List
            List {
                Section {
                    if upperItems.isEmpty {
                        EmptyStateView(icon: "star", message: "暂无常用功能")
                    } else {
                        ForEach(upperItems) { item in
                            CompactItemRow(item: item)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                dataManager.deleteItem(upperItems[index])
                            }
                        }
                    }
                } header: {
                    Text("常用功能")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }

                Section {
                    if lowerItemsGrouped.isEmpty {
                        EmptyStateView(icon: "apps.iphone", message: "暂无应用项目")
                    } else {
                        ForEach(lowerItemsGrouped.keys.sorted(), id: \.self) { appId in
                            DisclosureGroup {
                                ForEach(lowerItemsGrouped[appId] ?? []) { item in
                                    CompactItemRow(item: item)
                                        .padding(.leading, 8)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "app")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 12))
                                    Text(appId)
                                        .font(.system(size: 12))
                                    Spacer()
                                    Text("\(lowerItemsGrouped[appId]?.count ?? 0)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.15))
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                } header: {
                    Text("应用项目")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
            }
            .listStyle(.sidebar)
        }
    }
}

// MARK: - Advanced Tab

struct AdvancedTab: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    @ObservedObject var hotkeyManager = HotkeyManager.shared
    @ObservedObject var updateManager = UpdateManager.shared
    @State private var showingResetAlert = false
    @State private var isRecordingHotkey = false
    @State private var accessibilityGranted = PermissionManager.shared.checkAccessibilityPermission()

    private var accessibilityStatusText: String {
        accessibilityGranted ? "已授权" : "未授权"
    }

    private var accessibilityStatusColor: Color {
        accessibilityGranted ? .green : .orange
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    SettingRow(
                        icon: "keyboard",
                        title: "全局快捷键",
                        subtitle: "使用键盘快捷键呼出/隐藏面板"
                    ) {
                        Toggle("", isOn: Binding(
                            get: { hotkeyManager.isEnabled },
                            set: { newValue in
                                hotkeyManager.updateHotkey(
                                    keyCode: hotkeyManager.currentKeyCode,
                                    modifiers: hotkeyManager.currentModifiers,
                                    enabled: newValue
                                )
                            }
                        ))
                        .labelsHidden()
                    }

                    if hotkeyManager.isEnabled {
                        HStack(spacing: 12) {
                            Text("快捷键")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)

                            HotkeyRecorderView(
                                keyCode: hotkeyManager.currentKeyCode,
                                modifiers: hotkeyManager.currentModifiers,
                                isRecording: $isRecordingHotkey,
                                onHotkeyRecorded: { keyCode, modifiers in
                                    hotkeyManager.updateHotkey(
                                        keyCode: keyCode,
                                        modifiers: modifiers,
                                        enabled: true
                                    )
                                }
                            )

                            Spacer()
                        }
                        .padding(.leading, 36)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                Divider()

                SettingRow(
                    icon: "power",
                    title: "开机自启动",
                    subtitle: "登录时自动启动 Quick Panel"
                ) {
                    Toggle("", isOn: Binding(
                        get: { settingsManager.settings.launchAtLogin },
                        set: { newValue in
                            let success = LoginItemManager.shared.setLaunchAtLogin(newValue)
                            if success {
                                settingsManager.settings.launchAtLogin = newValue
                            }
                        }
                    ))
                    .labelsHidden()
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "accessibility")
                            .foregroundColor(accessibilityStatusColor)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("辅助功能权限")
                                .font(.system(size: 13, weight: .medium))
                            Text(accessibilityGranted ? "当前已授权，可稳定监听鼠标中键" : "建议授权，以获得更稳定的全局鼠标监听能力")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(accessibilityStatusText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(accessibilityStatusColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(accessibilityStatusColor.opacity(0.12))
                            .cornerRadius(8)
                    }

                    HStack(spacing: 8) {
                        Button("打开系统设置") {
                            PermissionManager.shared.openAccessibilitySettings()
                        }
                        .buttonStyle(.bordered)

                        Button("刷新状态") {
                            refreshAccessibilityStatus()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.leading, 32)
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("重置设置")
                                .font(.system(size: 13, weight: .medium))
                            Text("恢复所有设置为默认值")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    Button(action: {
                        showingResetAlert = true
                    }) {
                        Text("恢复默认设置")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .padding(.leading, 32)
                    .alert("确认恢复", isPresented: $showingResetAlert) {
                        Button("取消", role: .cancel) {}
                        Button("恢复", role: .destructive) {
                            settingsManager.resetToDefaults()
                        }
                    } message: {
                        Text("这将恢复所有设置为默认值，但不会删除已添加的项目。")
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("应用信息")
                            .font(.system(size: 13, weight: .medium))
                    }

                    VStack(spacing: 8) {
                        InfoRow(label: "版本", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        InfoRow(label: "构建号", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                    }
                    .padding(.leading, 32)

                    Button(action: {
                        updateManager.checkForUpdates(silent: false)
                    }) {
                        HStack(spacing: 6) {
                            if updateManager.isChecking {
                                ProgressView().scaleEffect(0.7)
                            } else {
                                Image(systemName: updateManager.hasUpdate ? "arrow.down.circle.fill" : "arrow.triangle.2.circlepath")
                            }
                            Text(updateManager.isChecking ? "检查中..." : (updateManager.hasUpdate ? "发现新版本，点击更新" : "检查更新"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(updateManager.hasUpdate ? .green : .blue)
                    .disabled(updateManager.isChecking)
                    .padding(.leading, 32)
                }
            }
            .padding(24)
            .animation(.easeInOut(duration: 0.2), value: hotkeyManager.isEnabled)
        }
        .onAppear {
            refreshAccessibilityStatus()
        }
    }

    private func refreshAccessibilityStatus() {
        accessibilityGranted = PermissionManager.shared.checkAccessibilityPermission()
    }
}

// MARK: - Hotkey Recorder View

struct HotkeyRecorderView: View {
    let keyCode: UInt32
    let modifiers: UInt32
    @Binding var isRecording: Bool
    let onHotkeyRecorded: (UInt32, UInt32) -> Void

    var displayText: String {
        if isRecording {
            return "请按下快捷键..."
        }
        return HotkeyManager.displayString(keyCode: keyCode, modifiers: modifiers)
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(displayText)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(isRecording ? .orange : .primary)

            if isRecording {
                Button(action: { isRecording = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isRecording ? Color.orange.opacity(0.1) : Color.secondary.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isRecording ? Color.orange : Color.secondary.opacity(0.3), lineWidth: 1)
        )
        .onTapGesture {
            isRecording = true
        }
        .background(
            HotkeyRecorderNSView(
                isRecording: $isRecording,
                onHotkeyRecorded: onHotkeyRecorded
            )
            .frame(width: 0, height: 0)
        )
    }
}

// MARK: - NSView Bridge for Key Event Capture

struct HotkeyRecorderNSView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onHotkeyRecorded: (UInt32, UInt32) -> Void

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onKeyRecorded = { keyCode, modifiers in
            onHotkeyRecorded(keyCode, modifiers)
            DispatchQueue.main.async {
                isRecording = false
            }
        }
        return view
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.isRecordingActive = isRecording
        if isRecording {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

class KeyCaptureView: NSView {
    var onKeyRecorded: ((UInt32, UInt32) -> Void)?
    var isRecordingActive = false
    private var localMonitor: Any?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        setupMonitor()
    }

    private func setupMonitor() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isRecordingActive else { return event }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let hasModifier = modifiers.contains(.command) || modifiers.contains(.control) || modifiers.contains(.option)

            guard hasModifier else { return event }

            let carbonMods = HotkeyManager.nsModifiersToCarbon(modifiers)
            self.onKeyRecorded?(UInt32(event.keyCode), carbonMods)

            return nil
        }
    }

    deinit {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

// MARK: - Helper Views

struct SettingRow<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let content: Content

    init(icon: String, title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            content
        }
    }
}

struct PreviewRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .font(.system(size: 12))
                .frame(width: 20)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(.vertical, 4)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(.vertical, 4)
    }
}

struct EmptyStateView: View {
    let icon: String
    let message: String

    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.secondary.opacity(0.5))
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 20)
            Spacer()
        }
        .listRowBackground(Color.clear)
    }
}

struct CompactItemRow: View {
    let item: PanelItem

    var body: some View {
        HStack(spacing: 8) {
            if let icon = item.getIcon() {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 12))
                Text(item.type == .application ? "应用" : "网站")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                AddItemWindowManager.shared.showEditItemWindow(item: item)
            }) {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)

            Button(action: {
                DataManager.shared.deleteItem(item)
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
        }
        .padding(.vertical, 2)
    }
}
