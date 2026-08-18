//
//  NewPanelView.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import SwiftUI
import UniformTypeIdentifiers

struct NewPanelView: View {
    @ObservedObject var dataManager = DataManager.shared
    @State private var showingAddSheet = false
    @State private var currentPage = 0
    @State private var addToLayer: PanelLayer = .upper

    let itemsPerPage = 12  // 3x4 grid per layer

    var upperItems: [PanelItem] {
        dataManager.getItems(for: .upper)
    }

    var lowerItems: [PanelItem] {
        dataManager.getItems(for: .lower)
    }

    var upperPages: Int {
        max(1, Int(ceil(Double(upperItems.count) / Double(itemsPerPage))))
    }

    var lowerPages: Int {
        max(1, Int(ceil(Double(lowerItems.count) / Double(itemsPerPage))))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            TopToolbarView()

            // Upper layer
            LayerView(
                items: upperItems,
                currentPage: $currentPage,
                itemsPerPage: itemsPerPage,
                layer: .upper,
                onAddItem: {
                    addToLayer = .upper
                    showingAddSheet = true
                }
            )

            // Divider with label
            HStack {
                Text("常用功能")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.6))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)

            // Lower layer
            LayerView(
                items: lowerItems,
                currentPage: $currentPage,
                itemsPerPage: itemsPerPage,
                layer: .lower,
                onAddItem: {
                    addToLayer = .lower
                    showingAddSheet = true
                }
            )
        }
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 12)
        .sheet(isPresented: $showingAddSheet) {
            AddItemView()
        }
    }
}

// MARK: - Top Toolbar
struct TopToolbarView: View {
    var body: some View {
        HStack(spacing: 12) {
            // Drag handle (left side)
            DragIndicator()

            Spacer()

            // Settings button
            Button(action: {
                // TODO: Open settings
            }) {
                Image(systemName: "gear")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            // Close button
            Button(action: {
                NotificationCenter.default.post(name: .hidePanel, object: nil)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct DragIndicator: View {
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { _ in
                Circle()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 4, height: 4)
            }
        }
    }
}

// MARK: - Layer View
struct LayerView: View {
    let items: [PanelItem]
    @Binding var currentPage: Int
    let itemsPerPage: Int
    let layer: PanelLayer
    let onAddItem: () -> Void

    @State private var localPage = 0
    @State private var scrollWheelMonitor: Any?

    var totalPages: Int {
        max(1, Int(ceil(Double(items.count) / Double(itemsPerPage))))
    }

    var currentPageItems: [PanelItem] {
        let start = localPage * itemsPerPage
        let end = min(start + itemsPerPage, items.count)
        guard start < items.count else { return [] }
        return Array(items[start..<end])
    }

    let columns = Array(repeating: GridItem(.fixed(80), spacing: 12), count: 4)

    var body: some View {
        VStack(spacing: 8) {
            // Grid
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(currentPageItems) { item in
                    CardItemButton(item: item)
                }

                // Add button
                if currentPageItems.count < itemsPerPage {
                    CardAddButton(action: onAddItem)
                }
            }
            .frame(height: 3 * 96 + 2 * 12) // 3 rows, fixed height
            .padding(.horizontal, 16)

            // Page indicator
            if totalPages > 1 {
                PageIndicator(currentPage: $localPage, totalPages: totalPages)
                    .padding(.bottom, 8)
            }
        }
        .padding(.vertical, 12)
        .onAppear {
            guard scrollWheelMonitor == nil else { return }
            scrollWheelMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                handleScrollWheel(event)
                return event
            }
        }
        .onDisappear {
            if let scrollWheelMonitor {
                NSEvent.removeMonitor(scrollWheelMonitor)
                self.scrollWheelMonitor = nil
            }
        }
    }

    private func handleScrollWheel(_ event: NSEvent) -> Void {
        guard totalPages > 1 else { return }

        if event.scrollingDeltaY > 5 {
            // Scroll up - previous page
            if localPage > 0 {
                withAnimation {
                    localPage -= 1
                }
            }
        } else if event.scrollingDeltaY < -5 {
            // Scroll down - next page
            if localPage < totalPages - 1 {
                withAnimation {
                    localPage += 1
                }
            }
        }
    }
}

// MARK: - Card Item Button
struct CardItemButton: View {
    let item: PanelItem
    @State private var isHovered = false
    @State private var showingEditSheet = false
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 8) {
            // Icon
            if let icon = item.getIcon() {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
            }

            // Name
            Text(item.name)
                .font(.system(size: 11))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
        }
        .frame(width: 80, height: 96)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(isHovered || isDragging ? 0.08 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .opacity(isDragging ? 0.5 : 1.0)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            handleItemClick()
        }
        .onDrag {
            isDragging = true
            return NSItemProvider(object: item.id.uuidString as NSString)
        }
        .onDrop(of: [.text], delegate: DropDelegate(item: item, isDragging: $isDragging))
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

        // Hide panel after launching
        NotificationCenter.default.post(name: .hidePanel, object: nil)
    }
}

// MARK: - Card Add Button
struct CardAddButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
        }
        .frame(width: 80, height: 96)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(isHovered ? 0.06 : 0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .foregroundColor(.secondary.opacity(0.4))
                )
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            action()
        }
    }
}

// MARK: - Page Indicator
struct PageIndicator: View {
    @Binding var currentPage: Int
    let totalPages: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(currentPage == index ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
                    .onTapGesture {
                        currentPage = index
                    }
            }
        }
    }
}

// MARK: - Drop Delegate for Drag & Drop Reordering
struct DropDelegate: SwiftUI.DropDelegate {
    let item: PanelItem
    @Binding var isDragging: Bool

    func performDrop(info: DropInfo) -> Bool {
        isDragging = false
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let itemProviders = info.itemProviders(for: [.text]).first else { return }

        itemProviders.loadItem(forTypeIdentifier: "public.text", options: nil) { (data, error) in
            guard let data = data as? Data,
                  let draggedIdString = String(data: data, encoding: .utf8),
                  let draggedId = UUID(uuidString: draggedIdString) else {
                return
            }

            DispatchQueue.main.async {
                let allItems = DataManager.shared.items
                guard let fromIndex = allItems.firstIndex(where: { $0.id == draggedId }),
                      let toIndex = allItems.firstIndex(where: { $0.id == item.id }),
                      fromIndex != toIndex else {
                    return
                }

                // Only allow reordering within the same layer
                if allItems[fromIndex].layer == allItems[toIndex].layer {
                    let targetItem = allItems[toIndex]
                    let settings = SettingsManager.shared.settings
                    DataManager.shared.moveItem(
                        id: draggedId,
                        layer: targetItem.layer,
                        appBundleIdentifier: targetItem.appBundleIdentifier,
                        toPage: targetItem.page,
                        slotIndex: targetItem.slot,
                        itemsPerPage: settings.itemsPerPage(for: targetItem.layer)
                    )
                }
            }
        }
    }

    func dropExited(info: DropInfo) {
        isDragging = false
    }
}
