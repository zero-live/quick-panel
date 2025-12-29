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

    @State private var name = ""
    @State private var itemType: ItemType = .application
    @State private var layer: PanelLayer = .upper
    @State private var path = ""
    @State private var browserPath: String?
    @State private var customIcon: NSImage?
    @State private var isFetchingIcon = false
    @State private var bindToCurrentApp = false
    @State private var selectedAppBundleId: String?

    init(presetLayer: PanelLayer = .upper, presetAppBundleId: String? = nil, presetAppName: String? = nil) {
        self.presetLayer = presetLayer
        self.presetAppBundleId = presetAppBundleId
        self.presetAppName = presetAppName
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("添加项目")
                .font(.title2)
                .bold()

            Form {
                Picker("层级", selection: $layer) {
                    Text("上层（常用）").tag(PanelLayer.upper)
                    Text("下层").tag(PanelLayer.lower)
                }
                .pickerStyle(.segmented)
                .disabled(presetLayer == .lower && presetAppBundleId != nil)

                // Show app binding option for lower layer
                if layer == .lower, let appName = presetAppName, let appBundleId = presetAppBundleId {
                    Toggle("绑定到当前应用 (\(appName))", isOn: $bindToCurrentApp)
                        .onChange(of: bindToCurrentApp) { _, newValue in
                            selectedAppBundleId = newValue ? appBundleId : nil
                        }
                }

                Picker("类型", selection: $itemType) {
                    Text("应用程序").tag(ItemType.application)
                    Text("网站").tag(ItemType.website)
                }
                .pickerStyle(.segmented)

                TextField("名称", text: $name)

                if itemType == .application {
                    HStack {
                        TextField("应用路径", text: $path)
                        Button("选择...") {
                            selectApplication()
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("网址", text: $path)
                            .textContentType(.URL)
                            .onChange(of: path) { oldValue, newValue in
                                // Auto-fill name from domain if name is empty
                                if name.isEmpty,
                                   let url = URLNormalizer.normalizedURL(from: newValue),
                                   let host = url.host {
                                    name = host
                                }
                            }

                        HStack {
                            if let icon = customIcon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 32, height: 32)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Button(isFetchingIcon ? "获取中..." : "自动获取图标") {
                                    fetchWebsiteIcon()
                                }
                                .disabled(path.isEmpty || isFetchingIcon)

                                Button("选择本地图标...") {
                                    selectImageFile()
                                }
                            }

                            if customIcon != nil {
                                Button("清除图标") {
                                    customIcon = nil
                                }
                            }
                        }
                    }
                }
            }
            .padding()

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
                .disabled(name.isEmpty || path.isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: itemType == .website ? 350 : 300)
        .onAppear {
            // Initialize with preset values
            layer = presetLayer
            if presetLayer == .lower, let bundleId = presetAppBundleId {
                bindToCurrentApp = true
                selectedAppBundleId = bundleId
            }
        }
    }

    private func selectApplication() {
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
        guard !path.isEmpty else { return }

        print("🧭 Fetch website icon: \(path)")
        isFetchingIcon = true
        IconFetcher.shared.fetchFavicon(for: path) { image in
            if let image = image {
                print("✅ Website icon fetched (\(image.size.width)x\(image.size.height)) for \(path)")
            } else {
                print("⚠️ Website icon fetch returned nil for \(path)")
            }
            self.customIcon = image
            self.isFetchingIcon = false
        }
    }

    private func addItem() {
        var iconData: Data?
        if let icon = customIcon, let tiffData = icon.tiffRepresentation {
            iconData = tiffData
        }

        let layerItems = DataManager.shared.getItems(for: layer)
        let newItem = PanelItem(
            name: name,
            type: itemType,
            path: path,
            iconData: iconData,
            browserPath: browserPath,
            layer: layer,
            appBundleIdentifier: selectedAppBundleId,
            order: layerItems.count
        )

        DataManager.shared.addItem(newItem)

        // Close the window
        AddItemWindowManager.shared.closeAddItemWindow()
        onDismiss?()
        dismiss()
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

    init(item: PanelItem) {
        self.item = item
        _name = State(initialValue: item.name)
        _layer = State(initialValue: item.layer)
        _path = State(initialValue: item.path)
        _browserPath = State(initialValue: item.browserPath)
        _customIcon = State(initialValue: item.iconData != nil ? NSImage(data: item.iconData!) : nil)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("编辑项目")
                .font(.title2)
                .bold()

            Form {
                Picker("层级", selection: $layer) {
                    Text("上层（常用）").tag(PanelLayer.upper)
                    Text("下层").tag(PanelLayer.lower)
                }
                .pickerStyle(.segmented)

                TextField("名称", text: $name)

                if item.type == .application {
                    HStack {
                        TextField("应用路径", text: $path)
                        Button("选择...") {
                            selectApplication()
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("网址", text: $path)
                            .textContentType(.URL)

                        HStack {
                            if let icon = customIcon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 32, height: 32)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Button(isFetchingIcon ? "获取中..." : "自动获取图标") {
                                    fetchWebsiteIcon()
                                }
                                .disabled(path.isEmpty || isFetchingIcon)

                                Button("选择本地图标...") {
                                    selectImageFile()
                                }
                            }

                            if customIcon != nil {
                                Button("清除图标") {
                                    customIcon = nil
                                }
                            }
                        }
                    }
                }
            }
            .padding()

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
                .disabled(name.isEmpty || path.isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: item.type == .website ? 300 : 250)
    }

    private func selectApplication() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
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
        guard !path.isEmpty else { return }

        print("🧭 Fetch website icon (edit): \(path)")
        isFetchingIcon = true
        IconFetcher.shared.fetchFavicon(for: path) { image in
            if let image = image {
                print("✅ Website icon fetched (\(image.size.width)x\(image.size.height)) for \(path)")
            } else {
                print("⚠️ Website icon fetch returned nil for \(path)")
            }
            self.customIcon = image
            self.isFetchingIcon = false
        }
    }

    private func saveItem() {
        var iconData: Data?
        if let icon = customIcon, let tiffData = icon.tiffRepresentation {
            iconData = tiffData
        }

        var updatedItem = item
        updatedItem.name = name
        updatedItem.layer = layer
        updatedItem.path = path
        updatedItem.browserPath = browserPath
        updatedItem.iconData = iconData

        DataManager.shared.updateItem(updatedItem)
        dismiss()
    }
}
