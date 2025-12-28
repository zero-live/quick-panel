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
    @State private var tempColumns: Int = 4
    @State private var tempRows: Int = 3
    @State private var tempSpacing: Double = 16

    var previewItemsPerPage: Int {
        tempColumns * tempRows
    }

    var previewPanelWidth: CGFloat {
        CGFloat(tempColumns) * 70 + CGFloat(tempColumns - 1) * tempSpacing + 40
    }

    var previewLayerHeight: CGFloat {
        CGFloat(tempRows) * 90 + CGFloat(tempRows - 1) * tempSpacing + 48
    }

    var hasChanges: Bool {
        tempColumns != settingsManager.settings.gridColumns ||
        tempRows != settingsManager.settings.gridRows ||
        tempSpacing != settingsManager.settings.itemSpacing
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content area with ScrollView
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Columns
                    SettingRow(
                        icon: "square.split.2x1",
                        title: "列数",
                        subtitle: "每行显示的项目数量"
                    ) {
                        Stepper("\(tempColumns)", value: $tempColumns, in: 2...6)
                            .frame(width: 80)
                    }

                    Divider()

                    // Rows
                    SettingRow(
                        icon: "square.split.1x2",
                        title: "行数",
                        subtitle: "每列显示的项目数量"
                    ) {
                        Stepper("\(tempRows)", value: $tempRows, in: 2...5)
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
                            PreviewRow(icon: "square.grid.3x3", label: "每页", value: "\(previewItemsPerPage) 项")
                            PreviewRow(icon: "aspectratio", label: "尺寸", value: "\(Int(previewPanelWidth)) × \(Int(previewLayerHeight * 2 + 44)) pt")
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
        tempColumns = settingsManager.settings.gridColumns
        tempRows = settingsManager.settings.gridRows
        tempSpacing = settingsManager.settings.itemSpacing
    }

    private func applyChanges() {
        settingsManager.batchUpdate { settings in
            settings.gridColumns = tempColumns
            settings.gridRows = tempRows
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

                Button(action: {
                    AddItemWindowManager.shared.showAddItemWindow(layer: .upper, appBundleId: nil, appName: nil)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("添加")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
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
    @State private var showingResetAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Launch at Login
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

                // Reset Settings
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

                // App Information
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
                }
            }
            .padding(24)
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
