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
    @State private var name = ""
    @State private var itemType: ItemType = .application
    @State private var path = ""
    @State private var browserPath: String?
    @State private var customIcon: NSImage?
    @State private var isFetchingIcon = false

    var body: some View {
        VStack(spacing: 20) {
            Text("添加项目")
                .font(.title2)
                .bold()

            Form {
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
                                if name.isEmpty, let url = URL(string: newValue), let host = url.host {
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

        isFetchingIcon = true
        IconFetcher.shared.fetchFavicon(for: path) { image in
            self.customIcon = image
            self.isFetchingIcon = false
        }
    }

    private func addItem() {
        var iconData: Data?
        if let icon = customIcon, let tiffData = icon.tiffRepresentation {
            iconData = tiffData
        }

        let newItem = PanelItem(
            name: name,
            type: itemType,
            path: path,
            iconData: iconData,
            browserPath: browserPath,
            order: DataManager.shared.items.count
        )

        DataManager.shared.addItem(newItem)
        dismiss()
    }
}

struct EditItemView: View {
    @Environment(\.dismiss) var dismiss
    let item: PanelItem

    @State private var name: String
    @State private var path: String
    @State private var browserPath: String?
    @State private var customIcon: NSImage?
    @State private var isFetchingIcon = false

    init(item: PanelItem) {
        self.item = item
        _name = State(initialValue: item.name)
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

        isFetchingIcon = true
        IconFetcher.shared.fetchFavicon(for: path) { image in
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
        updatedItem.path = path
        updatedItem.browserPath = browserPath
        updatedItem.iconData = iconData

        DataManager.shared.updateItem(updatedItem)
        dismiss()
    }
}
