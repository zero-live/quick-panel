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
                    TextField("网址", text: $path)
                        .textContentType(.URL)
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
        .frame(width: 500, height: 300)
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

    private func addItem() {
        let newItem = PanelItem(
            name: name,
            type: itemType,
            path: path,
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

    init(item: PanelItem) {
        self.item = item
        _name = State(initialValue: item.name)
        _path = State(initialValue: item.path)
        _browserPath = State(initialValue: item.browserPath)
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
                    TextField("网址", text: $path)
                        .textContentType(.URL)
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
        .frame(width: 500, height: 250)
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

    private func saveItem() {
        var updatedItem = item
        updatedItem.name = name
        updatedItem.path = path
        updatedItem.browserPath = browserPath

        DataManager.shared.updateItem(updatedItem)
        dismiss()
    }
}
