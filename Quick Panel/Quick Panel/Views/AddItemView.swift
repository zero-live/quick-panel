//
//  AddItemView.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AddItemView: View {
    @Environment(\.dismiss) var dismiss

    var onDismiss: (() -> Void)? = nil
    let presetLayer: PanelLayer
    let presetAppBundleId: String?
    let presetAppName: String?
    let targetPage: Int

    @State private var name = ""
    @State private var itemType: ItemType = .application
    @State private var layer: PanelLayer = .upper
    @State private var path = ""
    @State private var browserPath: String?
    @State private var customIcon: NSImage?
    @State private var isFetchingIcon = false
    @State private var lastAutoFilledWebsiteName: String?
    @State private var bindToCurrentApp = false
    @State private var selectedAppBundleId: String?
    @State private var selectedAppName: String?
    @State private var validationMessage: String?
    private let logCategory: AppLogCategory = .addItem

    init(presetLayer: PanelLayer = .upper, presetAppBundleId: String? = nil, presetAppName: String? = nil, targetPage: Int = 0) {
        self.presetLayer = presetLayer
        self.presetAppBundleId = presetAppBundleId
        self.presetAppName = presetAppName
        self.targetPage = targetPage
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("添加项目")
                        .font(.title2)
                        .bold()

                    Form {
                        Picker("层级", selection: $layer) {
                            Text("上层（常用）").tag(PanelLayer.upper)
                            Text("下层").tag(PanelLayer.lower)
                        }
                        .pickerStyle(.segmented)

                        if layer == .lower {
                            lowerLayerBindingSection
                        }

                        Picker("类型", selection: $itemType) {
                            Text("网站").tag(ItemType.website)
                            Text("应用程序").tag(ItemType.application)
                        }
                        .pickerStyle(.segmented)

                        TextField("名称", text: $name)

                        if itemType == .application {
                            HStack(spacing: 10) {
                                TextField("应用路径", text: $path)
                                Button("选择...") {
                                    selectItemApplication()
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                TextField("网址", text: $path)
                                    .textContentType(.URL)
                                    .onChange(of: path) { _, newValue in
                                        handleWebsiteURLChange(newValue)
                                    }

                                WebsiteIconEditor(
                                    icon: customIcon,
                                    isFetchingIcon: isFetchingIcon,
                                    hasURL: !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                    onFetchIcon: fetchWebsiteIcon,
                                    onSelectLocalIcon: selectImageFile,
                                    onClearIcon: {
                                        customIcon = nil
                                    }
                                )
                            }
                        }
                    }

                    if let validationMessage {
                        InlineValidationMessage(message: validationMessage)
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Button("取消") {
                    AddItemWindowManager.shared.closeAddItemWindow()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("添加") {
                    addItem()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 560, minHeight: 420)
        .onAppear {
            initializeForm()
        }
        .onChange(of: layer) { _, newLayer in
            handleLayerChange(newLayer)
        }
    }

    private var canSave: Bool {
        let hasBaseFields = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        guard hasBaseFields else { return false }

        if layer == .lower {
            return selectedAppBundleId != nil
        }

        return true
    }

    private var lowerLayerBindingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsBindToCurrentAppToggle {
                Toggle(bindToCurrentAppTitle, isOn: $bindToCurrentApp)
                    .onChange(of: bindToCurrentApp) { _, newValue in
                        handleBindToCurrentAppChange(newValue)
                    }
            }

            AppBindingSummaryCard(
                appName: selectedAppName,
                bundleIdentifier: selectedAppBundleId,
                icon: selectedBindingAppIcon,
                selectAction: selectBindingApplication,
                clearAction: addBindingClearAction
            )

            if selectedAppBundleId == nil {
                Text("下层项目必须绑定一个目标应用，否则主面板不会显示。")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
            }
        }
    }

    private var selectedBindingAppIcon: NSImage? {
        guard let selectedAppBundleId,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: selectedAppBundleId) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }

    private var showsBindToCurrentAppToggle: Bool {
        presetAppName != nil && presetAppBundleId != nil
    }

    private var bindToCurrentAppTitle: String {
        "绑定到当前应用 (\(presetAppName ?? "当前应用"))"
    }

    private var addBindingClearAction: (() -> Void)? {
        if selectedAppBundleId != nil {
            return clearSelectedBinding
        }
        return nil
    }

    private func handleBindToCurrentAppChange(_ newValue: Bool) {
        guard let appBundleId = presetAppBundleId, let appName = presetAppName else { return }

        if newValue {
            selectedAppBundleId = appBundleId
            selectedAppName = appName
        } else if selectedAppBundleId == appBundleId {
            selectedAppBundleId = nil
            selectedAppName = nil
        }
    }

    private func initializeForm() {
        layer = presetLayer

        if presetLayer == .lower, let bundleId = presetAppBundleId {
            bindToCurrentApp = true
            selectedAppBundleId = bundleId
            selectedAppName = presetAppName
        }
    }

    private func handleLayerChange(_ newLayer: PanelLayer) {
        guard newLayer == .lower else {
            clearSelectedBinding()
            bindToCurrentApp = false
            return
        }

        if let presetAppBundleId, let presetAppName {
            bindToCurrentApp = true
            selectedAppBundleId = presetAppBundleId
            selectedAppName = presetAppName
        }
    }

    private func selectItemApplication() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
            if name.isEmpty {
                name = url.deletingPathExtension().lastPathComponent
            }
        }
    }

    private func selectBindingApplication() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        if panel.runModal() == .OK, let url = panel.url {
            let bundle = Bundle(url: url)
            selectedAppBundleId = bundle?.bundleIdentifier
            selectedAppName = url.deletingPathExtension().lastPathComponent

            if let presetAppBundleId {
                bindToCurrentApp = selectedAppBundleId == presetAppBundleId
            }
        }
    }

    private func clearSelectedBinding() {
        selectedAppBundleId = nil
        selectedAppName = nil
    }

    private func selectImageFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.png, .jpeg, .image]
        panel.message = "选择图标文件"

        if panel.runModal() == .OK, let url = panel.url {
            if let image = NSImage(contentsOf: url) {
                customIcon = image
            }
        }
    }

    private func fetchWebsiteIcon() {
        guard let normalizedURL = normalizedWebsiteURL() else {
            validationMessage = "请输入有效的网址，例如 https://example.com"
            AppLogger.notice("网站图标抓取失败：URL 无效。", category: logCategory)
            return
        }

        let normalizedPath = normalizedURL.absoluteString
        path = normalizedPath
        validationMessage = nil

        isFetchingIcon = true
        AppLogger.debug("开始抓取网站元数据：\(normalizedPath)。", category: logCategory)
        IconFetcher.shared.fetchWebsiteMetadata(for: normalizedPath) { metadata in
            if let title = metadata.title {
                applyAutoFilledWebsiteName(title, fallbackURL: normalizedURL)
            }
            self.customIcon = metadata.icon
            self.isFetchingIcon = false
            AppLogger.info("网站元数据抓取完成：title=\(metadata.title ?? "nil")，icon=\(metadata.icon != nil ? "yes" : "no")。", category: logCategory)
        }
    }

    private func handleWebsiteURLChange(_ newValue: String) {
        guard let url = URLNormalizer.normalizedURL(from: newValue) else {
            if name == lastAutoFilledWebsiteName {
                name = ""
            }
            lastAutoFilledWebsiteName = nil
            return
        }

        let fallbackName = url.host ?? ""
        if name.isEmpty || name == lastAutoFilledWebsiteName {
            name = fallbackName
            lastAutoFilledWebsiteName = fallbackName
        }

        populateWebsiteTitleIfNeeded(for: url)
    }

    private func populateWebsiteTitleIfNeeded(for url: URL) {
        let currentName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldAutoFill = currentName.isEmpty || currentName == lastAutoFilledWebsiteName
        guard shouldAutoFill else { return }

        IconFetcher.shared.fetchWebsiteMetadata(for: url.absoluteString) { metadata in
            guard itemType == .website else { return }
            guard URLNormalizer.normalizedURL(from: path)?.absoluteString == url.absoluteString else { return }

            if let title = metadata.title {
                applyAutoFilledWebsiteName(title, fallbackURL: url)
            }

            if customIcon == nil, let icon = metadata.icon {
                customIcon = icon
            }
        }
    }

    private func applyAutoFilledWebsiteName(_ proposedName: String, fallbackURL: URL) {
        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = fallbackURL.host ?? ""
        let finalName = trimmedName.isEmpty ? fallbackName : trimmedName
        guard !finalName.isEmpty else { return }

        if name.isEmpty || name == lastAutoFilledWebsiteName || name == fallbackName {
            name = finalName
            lastAutoFilledWebsiteName = finalName
        }
    }

    private func addItem() {
        validationMessage = nil

        guard let validatedPath = validatedItemPath() else {
            return
        }

        var iconData: Data?
        if let icon = customIcon, let tiffData = icon.tiffRepresentation {
            iconData = tiffData
        }

        let bindingBundleId = layer == .lower ? selectedAppBundleId : nil
        let settings = SettingsManager.shared.settings
        let itemsPerPage = layer == .upper ? settings.upperItemsPerPage : settings.lowerItemsPerPage
        let layerItems = DataManager.shared.getItems(for: layer, appBundleIdentifier: bindingBundleId)

        let pageStartOrder = targetPage * itemsPerPage
        let pageEndOrder = pageStartOrder + itemsPerPage

        let usedOrders = Set(layerItems.filter { $0.order >= pageStartOrder && $0.order < pageEndOrder }.map(\.order))

        var targetOrder = pageStartOrder
        for order in pageStartOrder..<pageEndOrder {
            if !usedOrders.contains(order) {
                targetOrder = order
                break
            }
        }

        if usedOrders.count >= itemsPerPage {
            targetOrder = pageEndOrder
        }

        let newItem = PanelItem(
            name: name,
            type: itemType,
            path: validatedPath,
            iconData: iconData,
            browserPath: browserPath,
            layer: layer,
            appBundleIdentifier: bindingBundleId,
            order: targetOrder
        )

        DataManager.shared.addItem(newItem)
        AppLogger.notice("添加项目完成：name=\(name)，type=\(itemType.rawValue)，layer=\(layer.rawValue)。", category: logCategory)

        // Close the window
        AddItemWindowManager.shared.closeAddItemWindow()
        onDismiss?()
        dismiss()
    }

    private func validatedItemPath() -> String? {
        switch itemType {
        case .application:
            let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isValidApplicationPath(trimmedPath) else {
                validationMessage = "请选择有效的应用程序路径。"
                return nil
            }
            return trimmedPath
        case .website:
            guard let normalizedURL = normalizedWebsiteURL() else {
                validationMessage = "请输入有效的网址，例如 https://example.com"
                return nil
            }
            return normalizedURL.absoluteString
        }
    }

    private func normalizedWebsiteURL() -> URL? {
        URLNormalizer.normalizedURL(from: path)
    }
}

struct EditItemView: View {
    @Environment(\.dismiss) var dismiss
    let item: PanelItem

    @State private var name: String
    @State private var layer: PanelLayer
    @State private var path: String
    @State private var browserPath: String?
    @State private var customIcon: NSImage?
    @State private var isFetchingIcon = false
    @State private var lastAutoFilledWebsiteName: String?
    @State private var selectedAppBundleId: String?
    @State private var selectedAppName: String?
    @State private var validationMessage: String?
    private let logCategory: AppLogCategory = .addItem

    init(item: PanelItem) {
        self.item = item
        _name = State(initialValue: item.name)
        _layer = State(initialValue: item.layer)
        _path = State(initialValue: item.path)
        _browserPath = State(initialValue: item.browserPath)
        _customIcon = State(initialValue: item.iconData != nil ? NSImage(data: item.iconData!) : nil)
        _selectedAppBundleId = State(initialValue: item.appBundleIdentifier)
        _selectedAppName = State(initialValue: nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("编辑项目")
                        .font(.title2)
                        .bold()

                    Form {
                        Picker("层级", selection: $layer) {
                            Text("上层（常用）").tag(PanelLayer.upper)
                            Text("下层").tag(PanelLayer.lower)
                        }
                        .pickerStyle(.segmented)

                        if layer == .lower {
                            lowerLayerBindingSection
                        }

                        TextField("名称", text: $name)

                        if item.type == .application {
                            HStack(spacing: 10) {
                                TextField("应用路径", text: $path)
                                Button("选择...") {
                                    selectItemApplication()
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                TextField("网址", text: $path)
                                    .textContentType(.URL)
                                    .onChange(of: path) { _, newValue in
                                        handleWebsiteURLChange(newValue)
                                    }

                                WebsiteIconEditor(
                                    icon: customIcon,
                                    isFetchingIcon: isFetchingIcon,
                                    hasURL: !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                    onFetchIcon: fetchWebsiteIcon,
                                    onSelectLocalIcon: selectImageFile,
                                    onClearIcon: {
                                        customIcon = nil
                                    }
                                )
                            }
                        }
                    }

                    if let validationMessage {
                        InlineValidationMessage(message: validationMessage)
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("保存") {
                    saveItem()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 560, minHeight: 380)
        .onAppear {
            initializeForm()
        }
        .onChange(of: layer) { _, newLayer in
            if newLayer == .upper {
                selectedAppBundleId = nil
                selectedAppName = nil
            }
        }
    }

    private var canSave: Bool {
        let hasBaseFields = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        guard hasBaseFields else { return false }

        if layer == .lower {
            return selectedAppBundleId != nil
        }

        return true
    }

    private var lowerLayerBindingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppBindingSummaryCard(
                appName: selectedAppName ?? itemBindingDisplayName,
                bundleIdentifier: selectedAppBundleId,
                icon: selectedBindingAppIcon,
                selectAction: selectBindingApplication,
                clearAction: editBindingClearAction
            )

            if selectedAppBundleId == nil {
                Text("下层项目必须绑定一个目标应用，否则主面板不会显示。")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
            }
        }
    }

    private var itemBindingDisplayName: String {
        selectedAppName ?? item.appBundleIdentifier ?? "未选择"
    }

    private var selectedBindingAppIcon: NSImage? {
        guard let selectedAppBundleId,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: selectedAppBundleId) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }

    private var editBindingClearAction: (() -> Void)? {
        if selectedAppBundleId != nil {
            return clearSelectedBinding
        }
        return nil
    }

    private func initializeForm() {
        guard let bundleId = item.appBundleIdentifier else { return }
        selectedAppBundleId = bundleId
        selectedAppName = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)?
            .deletingPathExtension()
            .lastPathComponent
    }

    private func selectItemApplication() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
            if name == item.name || name.isEmpty {
                name = url.deletingPathExtension().lastPathComponent
            }
        }
    }

    private func selectBindingApplication() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        if panel.runModal() == .OK, let url = panel.url {
            let bundle = Bundle(url: url)
            selectedAppBundleId = bundle?.bundleIdentifier
            selectedAppName = url.deletingPathExtension().lastPathComponent
        }
    }

    private func clearSelectedBinding() {
        selectedAppBundleId = nil
        selectedAppName = nil
    }

    private func selectImageFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.png, .jpeg, .image]
        panel.message = "选择图标文件"

        if panel.runModal() == .OK, let url = panel.url {
            if let image = NSImage(contentsOf: url) {
                customIcon = image
            }
        }
    }

    private func fetchWebsiteIcon() {
        guard let normalizedURL = normalizedWebsiteURL() else {
            validationMessage = "请输入有效的网址，例如 https://example.com"
            AppLogger.notice("编辑网站图标抓取失败：URL 无效。", category: logCategory)
            return
        }

        let normalizedPath = normalizedURL.absoluteString
        path = normalizedPath
        validationMessage = nil

        isFetchingIcon = true
        AppLogger.debug("开始抓取编辑网站元数据：\(normalizedPath)。", category: logCategory)
        IconFetcher.shared.fetchWebsiteMetadata(for: normalizedPath) { metadata in
            if let title = metadata.title {
                applyAutoFilledWebsiteName(title, fallbackURL: normalizedURL)
            }
            self.customIcon = metadata.icon
            self.isFetchingIcon = false
            AppLogger.info("编辑网站元数据抓取完成：title=\(metadata.title ?? "nil")，icon=\(metadata.icon != nil ? "yes" : "no")。", category: logCategory)
        }
    }

    private func handleWebsiteURLChange(_ newValue: String) {
        guard let url = URLNormalizer.normalizedURL(from: newValue) else {
            if name == lastAutoFilledWebsiteName {
                name = ""
            }
            lastAutoFilledWebsiteName = nil
            return
        }

        let fallbackName = url.host ?? ""
        if name.isEmpty || name == lastAutoFilledWebsiteName {
            name = fallbackName
            lastAutoFilledWebsiteName = fallbackName
        }

        populateWebsiteTitleIfNeeded(for: url)
    }

    private func populateWebsiteTitleIfNeeded(for url: URL) {
        let currentName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldAutoFill = currentName.isEmpty || currentName == lastAutoFilledWebsiteName
        guard shouldAutoFill else { return }

        IconFetcher.shared.fetchWebsiteMetadata(for: url.absoluteString) { metadata in
            guard item.type == .website else { return }
            guard URLNormalizer.normalizedURL(from: path)?.absoluteString == url.absoluteString else { return }

            if let title = metadata.title {
                applyAutoFilledWebsiteName(title, fallbackURL: url)
            }

            if customIcon == nil, let icon = metadata.icon {
                customIcon = icon
            }
        }
    }

    private func applyAutoFilledWebsiteName(_ proposedName: String, fallbackURL: URL) {
        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = fallbackURL.host ?? ""
        let finalName = trimmedName.isEmpty ? fallbackName : trimmedName
        guard !finalName.isEmpty else { return }

        if name.isEmpty || name == lastAutoFilledWebsiteName || name == fallbackName {
            name = finalName
            lastAutoFilledWebsiteName = finalName
        }
    }

    private func saveItem() {
        validationMessage = nil

        guard let validatedPath = validatedItemPath() else {
            return
        }

        var iconData: Data?
        if let icon = customIcon, let tiffData = icon.tiffRepresentation {
            iconData = tiffData
        }

        var updatedItem = item
        updatedItem.name = name
        updatedItem.layer = layer
        updatedItem.path = validatedPath
        updatedItem.browserPath = browserPath
        updatedItem.iconData = iconData
        updatedItem.appBundleIdentifier = layer == .lower ? selectedAppBundleId : nil

        let targetBundleId = layer == .lower ? selectedAppBundleId : nil
        let scopeChanged = updatedItem.layer != item.layer || updatedItem.appBundleIdentifier != item.appBundleIdentifier

        if scopeChanged {
            let layerItems = DataManager.shared.getItems(for: layer, appBundleIdentifier: targetBundleId)
            updatedItem.order = (layerItems.map(\.order).max() ?? -1) + 1
        }

        DataManager.shared.updateItem(updatedItem)
        AppLogger.notice("保存项目完成：name=\(updatedItem.name)，type=\(item.type.rawValue)，layer=\(layer.rawValue)。", category: logCategory)
        dismiss()
    }

    private func validatedItemPath() -> String? {
        switch item.type {
        case .application:
            let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isValidApplicationPath(trimmedPath) else {
                validationMessage = "请选择有效的应用程序路径。"
                return nil
            }
            return trimmedPath
        case .website:
            guard let normalizedURL = normalizedWebsiteURL() else {
                validationMessage = "请输入有效的网址，例如 https://example.com"
                return nil
            }
            return normalizedURL.absoluteString
        }
    }

    private func normalizedWebsiteURL() -> URL? {
        URLNormalizer.normalizedURL(from: path)
    }
}

private func isValidApplicationPath(_ path: String) -> Bool {
    guard !path.isEmpty else { return false }

    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
    return exists && isDirectory.boolValue && path.lowercased().hasSuffix(".app")
}

private struct InlineValidationMessage: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WebsiteIconEditor: View {
    let icon: NSImage?
    let isFetchingIcon: Bool
    let hasURL: Bool
    let onFetchIcon: () -> Void
    let onSelectLocalIcon: () -> Void
    let onClearIcon: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                } else {
                    Image(systemName: "globe")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.secondary)
                        .padding(10)
                }
            }
            .frame(width: 44, height: 44)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(10)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Button(isFetchingIcon ? "获取中..." : "自动获取图标") {
                        onFetchIcon()
                    }
                    .disabled(!hasURL || isFetchingIcon)

                    Button("选择本地图标...") {
                        onSelectLocalIcon()
                    }
                }

                HStack(spacing: 8) {
                    if icon != nil {
                        Button("清除图标") {
                            onClearIcon()
                        }
                        .foregroundColor(.red)
                    }

                    Text(icon == nil ? "可留空，系统会使用默认图标" : "当前将使用自定义图标")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}

private struct AppBindingSummaryCard: View {
    let appName: String?
    let bundleIdentifier: String?
    let icon: NSImage?
    let selectAction: () -> Void
    let clearAction: (() -> Void)?

    private var subtitleText: String {
        if let bundleIdentifier,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return appURL.path
        }

        return bundleIdentifier ?? "请选择要绑定的目标应用"
    }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                } else {
                    Image(systemName: "app")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            }
            .frame(width: 40, height: 40)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text(appName ?? "未选择")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(bundleIdentifier == nil ? .secondary : .primary)

                Text(subtitleText)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("选择应用...") {
                selectAction()
            }

            if let clearAction {
                Button("清除") {
                    clearAction()
                }
                .foregroundColor(.red)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}
