//
//  PanelView.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import SwiftUI

struct PanelView: View {
    @ObservedObject var dataManager = DataManager.shared
    @State private var showingAddSheet = false

    let columns = Array(repeating: GridItem(.fixed(70), spacing: 16), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            // Upper grid - dynamic items
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(dataManager.items.prefix(12)) { item in
                    ItemButton(item: item)
                }

                // Add button if less than 12 items
                if dataManager.items.count < 12 {
                    AddItemButton {
                        showingAddSheet = true
                    }
                }
            }
            .padding(20)
        }
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        .sheet(isPresented: $showingAddSheet) {
            AddItemView()
        }
    }
}

// MARK: - Item Button
struct ItemButton: View {
    let item: PanelItem
    @State private var isHovered = false
    @State private var showingEditSheet = false

    var body: some View {
        VStack(spacing: 6) {
            if let icon = item.getIcon() {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isHovered ? Color.primary.opacity(0.1) : Color.clear)
                    )
            }

            Text(item.name)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(.primary)
                .frame(maxWidth: 70)
        }
        .frame(width: 70, height: 90)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            handleItemClick()
        }
        .contextMenu {
            Button("编辑") {
                showingEditSheet = true
            }
            Button("删除", role: .destructive) {
                DataManager.shared.deleteItem(item)
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditItemView(item: item)
        }
    }

    private func handleItemClick() {
        switch item.type {
        case .application:
            AppLauncher.shared.launchApp(at: item.path)
        case .website:
            AppLauncher.shared.openWebsite(url: item.path, browserPath: item.browserPath)
        }
    }
}

// MARK: - Add Button
struct AddItemButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "plus.circle")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
                .frame(width: 60, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isHovered ? Color.primary.opacity(0.1) : Color.clear)
                )

            Text("添加")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(maxWidth: 70)
        }
        .frame(width: 70, height: 90)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            action()
        }
    }
}

#Preview {
    PanelView()
        .frame(width: 360, height: 340)
}
