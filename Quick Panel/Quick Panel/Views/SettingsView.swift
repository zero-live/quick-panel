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
        .frame(minWidth: 600, minHeight: 500)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Image(systemName: "square.grid.2x2")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("上层网格")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                    }

                    SettingRow(
                        icon: "square.split.2x1",
                        title: "列数",
                        subtitle: "每行显示的项目数量"
                    ) {
                        Stepper("\(tempUpperColumns)", value: $tempUpperColumns, in: 3...5)
                            .frame(width: 80)
                    }

                    Divider()

                    SettingRow(
                        icon: "square.split.1x2",
                        title: "行数",
                        subtitle: "每列显示的项目数量"
                    ) {
                        Stepper("\(tempUpperRows)", value: $tempUpperRows, in: 3...5)
                            .frame(width: 80)
                    }

                    Divider()

                    HStack {
                        Image(systemName: "square.grid.2x2")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        Text("下层网格")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                    }

                    SettingRow(
                        icon: "square.split.2x1",
                        title: "列数",
                        subtitle: "每行显示的项目数量"
                    ) {
                        Stepper("\(tempLowerColumns)", value: $tempLowerColumns, in: 3...5)
                            .frame(width: 80)
                    }

                    Divider()

                    SettingRow(
                        icon: "square.split.1x2",
                        title: "行数",
                        subtitle: "每列显示的项目数量"
                    ) {
                        Stepper("\(tempLowerRows)", value: $tempLowerRows, in: 3...5)
                            .frame(width: 80)
                    }

                    Divider()

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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
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
    @State private var pendingDeleteItem: PanelItem?
    @State private var searchText = ""
    @State private var selectedFilter: ItemManagementFilter = .all

    var upperItems: [PanelItem] {
        filteredItems(dataManager.getItems(for: .upper))
    }

    var lowerItemGroups: [LowerItemGroup] {
        let groupedItems = Dictionary(grouping: filteredItems(dataManager.items.filter { $0.layer == .lower })) { item in
            item.appBundleIdentifier ?? LowerItemGroup.unboundIdentifier
        }

        return groupedItems.map { bundleIdentifier, items in
            LowerItemGroup(
                bundleIdentifier: bundleIdentifier == LowerItemGroup.unboundIdentifier ? nil : bundleIdentifier,
                items: items.sorted { $0.order < $1.order }
            )
        }
        .sorted { lhs, rhs in
            if lhs.isUnbound != rhs.isUnbound {
                return !lhs.isUnbound
            }
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "square.grid.3x3")
                            .foregroundColor(.blue)
                        Text("\(filteredItemCount) / \(dataManager.items.count) 个项目")
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

                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("搜索名称、路径或应用标识", text: $searchText)
                            .textFieldStyle(.plain)

                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .cornerRadius(8)

                    Picker("筛选", selection: $selectedFilter) {
                        ForEach(ItemManagementFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            List {
                Section {
                    if upperItems.isEmpty {
                        EmptyStateView(icon: "star", message: selectedFilter == .lower ? "当前筛选下无常用项目" : "暂无匹配的常用项目")
                    } else {
                        ForEach(upperItems) { item in
                            CompactItemRow(item: item) {
                                pendingDeleteItem = item
                            }
                        }
                        .onDelete { indexSet in
                            if let firstIndex = indexSet.first {
                                pendingDeleteItem = upperItems[firstIndex]
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
                    if lowerItemGroups.isEmpty {
                        EmptyStateView(icon: "apps.iphone", message: selectedFilter == .upper ? "当前筛选下无下层项目" : "暂无匹配的下层项目")
                    } else {
                        ForEach(lowerItemGroups) { group in
                            DisclosureGroup {
                                ForEach(group.items) { item in
                                    CompactItemRow(item: item) {
                                        pendingDeleteItem = item
                                    }
                                        .padding(.leading, 8)
                                }
                            } label: {
                                LowerItemGroupHeader(group: group)
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
        .alert("确认删除", isPresented: Binding(
            get: { pendingDeleteItem != nil },
            set: { newValue in
                if !newValue {
                    pendingDeleteItem = nil
                }
            }
        )) {
            Button("取消", role: .cancel) {
                pendingDeleteItem = nil
            }
            Button("删除", role: .destructive) {
                if let item = pendingDeleteItem {
                    dataManager.deleteItem(item)
                }
                pendingDeleteItem = nil
            }
        } message: {
            if let item = pendingDeleteItem {
                Text("将删除“\(item.name)”。此操作不可撤销。")
            } else {
                Text("此操作不可撤销。")
            }
        }
    }

    private var filteredItemCount: Int {
        filteredItems(dataManager.items).count
    }

    private func filteredItems(_ items: [PanelItem]) -> [PanelItem] {
        items.filter { item in
            matchesFilter(item) && matchesSearch(item)
        }
    }

    private func matchesFilter(_ item: PanelItem) -> Bool {
        switch selectedFilter {
        case .all:
            return true
        case .upper:
            return item.layer == .upper
        case .lower:
            return item.layer == .lower
        case .application:
            return item.type == .application
        case .website:
            return item.type == .website
        }
    }

    private func matchesSearch(_ item: PanelItem) -> Bool {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return true }

        let lowercasedKeyword = keyword.lowercased()
        return item.name.lowercased().contains(lowercasedKeyword) ||
            item.path.lowercased().contains(lowercasedKeyword) ||
            (item.appBundleIdentifier?.lowercased().contains(lowercasedKeyword) ?? false)
    }
}

enum ItemManagementFilter: String, CaseIterable, Identifiable {
    case all
    case upper
    case lower
    case application
    case website

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .upper:
            return "常用"
        case .lower:
            return "下层"
        case .application:
            return "应用"
        case .website:
            return "网站"
        }
    }
}

// MARK: - Lower Item Group

struct LowerItemGroup: Identifiable {
    static let unboundIdentifier = "__unbound__"

    let bundleIdentifier: String?
    let items: [PanelItem]

    var id: String {
        bundleIdentifier ?? Self.unboundIdentifier
    }

    var isUnbound: Bool {
        bundleIdentifier == nil
    }

    var displayName: String {
        if let applicationName {
            return applicationName
        }

        return isUnbound ? "未绑定应用" : (bundleIdentifier ?? "未知应用")
    }

    var subtitle: String {
        if let bundleIdentifier {
            return bundleIdentifier
        }
        return "这些项目未绑定到具体应用"
    }

    var itemCountText: String {
        "\(items.count)"
    }

    var icon: NSImage? {
        guard let applicationURL else { return nil }
        return NSWorkspace.shared.icon(forFile: applicationURL.path)
    }

    private var applicationURL: URL? {
        guard let bundleIdentifier else { return nil }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    private var applicationName: String? {
        if let applicationURL {
            return FileManager.default.displayName(atPath: applicationURL.path)
                .replacingOccurrences(of: ".app", with: "")
        }

        return nil
    }
}

struct LowerItemGroupHeader: View {
    let group: LowerItemGroup

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let icon = group.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                } else {
                    Image(systemName: group.isUnbound ? "questionmark.app" : "app")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(group.isUnbound ? .orange : .blue)
                        .padding(4)
                }
            }
            .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(group.displayName)
                    .font(.system(size: 12, weight: .medium))
                Text(group.subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(group.itemCountText)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(6)
        }
        .padding(.vertical, 2)
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
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshAccessibilityStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
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
        .padding(.vertical, 4)
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let tint: Color
    let content: Content

    init(title: String, icon: String, tint: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(tint)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                Spacer()
            }

            VStack(alignment: .leading, spacing: 14) {
                content
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.65))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .cornerRadius(10)
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
    let onDelete: () -> Void

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
                onDelete()
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
