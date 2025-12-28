//
//  PanelView.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import SwiftUI
import UniformTypeIdentifiers

struct PanelView: View {
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var contextDetector = ContextDetector.shared
    @State private var currentAppBundleId: String? = nil
    @State private var currentAppName: String = "当前应用"
    @State private var upperPage = 0
    @State private var lowerPage = 0
    @State private var lastActiveApp: (bundleId: String?, name: String) = (nil, "当前应用")

    let columns = Array(repeating: GridItem(.fixed(70), spacing: 16), count: 4)
    let itemsPerPage = 12  // 3x4 grid

    var upperItems: [PanelItem] {
        dataManager.getItems(for: .upper)
    }

    var lowerItems: [PanelItem] {
        // Filter by current app
        if let bundleId = currentAppBundleId {
            return dataManager.getItemsForCurrentApp(bundleIdentifier: bundleId)
        }
        return []
    }

    var upperPageCount: Int {
        max(1, Int(ceil(Double(max(upperItems.count, 1)) / Double(itemsPerPage))))
    }

    var lowerPageCount: Int {
        max(1, Int(ceil(Double(max(lowerItems.count, 1)) / Double(itemsPerPage))))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle at the top
            DragHandleView()
                .frame(height: 24)

            // Upper grid - common items
            LayerGridView(
                items: upperItems,
                page: $upperPage,
                itemsPerPage: itemsPerPage,
                layer: .upper,
                currentAppBundleId: nil,
                currentAppName: nil,
                title: "常用功能",
                columns: columns,
                onAdd: {
                    AddItemWindowManager.shared.showAddItemWindow(
                        layer: .upper,
                        appBundleId: nil,
                        appName: nil
                    )
                }
            )

            // Divider
            Divider()
                .padding(.horizontal, 20)

            // Lower grid - current app items
            LayerGridView(
                items: lowerItems,
                page: $lowerPage,
                itemsPerPage: itemsPerPage,
                layer: .lower,
                currentAppBundleId: currentAppBundleId,
                currentAppName: currentAppName,
                title: currentAppName,
                columns: columns,
                onAdd: {
                    AddItemWindowManager.shared.showAddItemWindow(
                        layer: .lower,
                        appBundleId: currentAppBundleId,
                        appName: currentAppName
                    )
                }
            )
        }
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        .onAppear {
            setupPanelShowObserver()
        }
    }

    private func setupPanelShowObserver() {
        // Listen for active app changes
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                // Track the last non-QuickPanel app
                if app.bundleIdentifier != Bundle.main.bundleIdentifier {
                    lastActiveApp = (app.bundleIdentifier, app.localizedName ?? "当前应用")
                    print("📱 Tracked active app: \(lastActiveApp.name) (\(lastActiveApp.bundleId ?? "nil"))")
                }
            }
        }

        // Listen for panel will show notification
        NotificationCenter.default.addObserver(
            forName: .panelWillShow,
            object: nil,
            queue: .main
        ) { [self] _ in
            updateCurrentApp()
        }

        // Initialize with current app
        updateCurrentApp()
    }

    private func updateCurrentApp() {
        // Use the last tracked active app
        currentAppBundleId = lastActiveApp.bundleId
        currentAppName = lastActiveApp.name
        print("📱 Updated panel to show app: \(currentAppName) (\(currentAppBundleId ?? "nil"))")
    }
}

// MARK: - Layer Grid View
struct LayerGridView: View {
    let items: [PanelItem]
    @Binding var page: Int
    let itemsPerPage: Int
    let layer: PanelLayer
    let currentAppBundleId: String?
    let currentAppName: String?
    let title: String
    let columns: [GridItem]
    let onAdd: () -> Void

    @ObservedObject private var dataManager = DataManager.shared
    @State private var showingGroupNameEditor = false
    @State private var editingGroupName = ""

    var pageCount: Int {
        max(1, Int(ceil(Double(max(items.count, 1)) / Double(itemsPerPage))))
    }

    private func validatePage() {
        // If current page exceeds page count, go back to last valid page
        if page >= pageCount {
            page = max(0, pageCount - 1)
        }
    }

    private func setupScrollObservers() {
        // Listen for scroll notifications
        NotificationCenter.default.addObserver(
            forName: .scrollPreviousPage,
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let layerString = userInfo["layer"] as? String,
                  layerString == (layer == .upper ? "upper" : "lower") else {
                return
            }

            if page > 0 {
                withAnimation {
                    page -= 1
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: .scrollNextPage,
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let layerString = userInfo["layer"] as? String,
                  layerString == (layer == .upper ? "upper" : "lower") else {
                return
            }

            if page < pageCount - 1 {
                withAnimation {
                    page += 1
                }
            }
        }
    }

    var currentPageItems: [PanelItem] {
        let start = page * itemsPerPage
        let end = min(start + itemsPerPage, items.count)
        guard start < items.count else { return [] }
        return Array(items[start..<end])
    }

    // Always show 12 slots
    var slotsToShow: Int { itemsPerPage }

    var currentGroupName: String? {
        dataManager.pageGroups.getGroupName(layer: layer, page: page)
    }

    var displayTitle: String {
        if let groupName = currentGroupName, !groupName.isEmpty {
            return groupName
        }
        return title
    }

    var body: some View {
        VStack(spacing: 8) {
            // Title with page info
            HStack {
                // Left: Current app name (for lower layer only)
                if layer == .lower, let appName = currentAppName {
                    Text(appName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                } else {
                    // Empty space for upper layer to balance layout
                    Text("")
                        .font(.system(size: 11, weight: .medium))
                }

                Spacer()

                // Right: Page count
                if pageCount > 1 {
                    Text("\(page + 1)/\(pageCount)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                } else {
                    // Empty space to balance layout
                    Text("")
                        .font(.system(size: 10))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .overlay(alignment: .center) {
                // Center: Group name (double-click to edit) - absolutely centered
                if let groupName = currentGroupName, !groupName.isEmpty {
                    Text(groupName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.blue.opacity(0.8))
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            editingGroupName = groupName
                            showingGroupNameEditor = true
                        }
                        .help("双击编辑分组名称")
                        .popover(isPresented: $showingGroupNameEditor) {
                            GroupNameEditorView(
                                groupName: $editingGroupName,
                                onSave: {
                                    let trimmedName = editingGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                                    dataManager.setPageGroup(
                                        layer: layer,
                                        page: page,
                                        name: trimmedName.isEmpty ? nil : trimmedName
                                    )
                                    showingGroupNameEditor = false
                                },
                                onCancel: {
                                    showingGroupNameEditor = false
                                }
                            )
                            .frame(width: 250, height: 100)
                        }
                } else {
                    // Invisible placeholder for double-click to add group name
                    Color.clear
                        .frame(width: 80, height: 16)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            editingGroupName = ""
                            showingGroupNameEditor = true
                        }
                        .popover(isPresented: $showingGroupNameEditor) {
                            GroupNameEditorView(
                                groupName: $editingGroupName,
                                onSave: {
                                    let trimmedName = editingGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                                    dataManager.setPageGroup(
                                        layer: layer,
                                        page: page,
                                        name: trimmedName.isEmpty ? nil : trimmedName
                                    )
                                    showingGroupNameEditor = false
                                },
                                onCancel: {
                                    showingGroupNameEditor = false
                                }
                            )
                            .frame(width: 250, height: 100)
                        }
                }
            }
            .onAppear {
                setupScrollObservers()
            }
            .onChange(of: items.count) { _, _ in
                validatePage()
            }

            LazyVGrid(columns: columns, spacing: 16) {
                // Show items for current page
                ForEach(currentPageItems) { item in
                    ItemButton(item: item, layer: layer)
                        .transition(.scale.combined(with: .opacity))
                }

                // Fill remaining slots with clickable empty placeholders
                ForEach(currentPageItems.count..<slotsToShow, id: \.self) { index in
                    EmptySlotView(
                        layer: layer,
                        currentAppBundleId: currentAppBundleId,
                        onAdd: onAdd
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPageItems.map { $0.id })

            // Page indicator if multiple pages
            if pageCount > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<pageCount, id: \.self) { index in
                        Circle()
                            .fill(page == index ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .onTapGesture {
                                withAnimation {
                                    page = index
                                }
                            }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Empty Slot
struct EmptySlotView: View {
    let layer: PanelLayer
    let currentAppBundleId: String?
    let onAdd: () -> Void
    @State private var isHovered = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)

            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isHovered ? Color.secondary.opacity(0.4) : Color.secondary.opacity(0.15),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )

            if isHovered {
                Image(systemName: "plus")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
        .frame(width: 70, height: 90)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onAdd()
        }
    }
}

// MARK: - Drag Handle
struct DragHandleView: View {
    var body: some View {
        VStack(spacing: 4) {
            Spacer()
            // Three dots indicator
            HStack(spacing: 4) {
                ForEach(0..<3) { _ in
                    Circle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 4, height: 4)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

// MARK: - Item Button
struct ItemButton: View {
    let item: PanelItem
    let layer: PanelLayer
    @State private var isHovered = false
    @State private var showingEditSheet = false
    @State private var isDragging = false
    @State private var isDropTarget = false
    @State private var scale: CGFloat = 1.0
    @State private var dragTimeoutTask: DispatchWorkItem?

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
        .scaleEffect(scale)
        .opacity(isDragging ? 0.0 : 1.0)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isDropTarget ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            handleItemClick()
        }
        .onDrag {
            withAnimation(.easeOut(duration: 0.15)) {
                isDragging = true
                scale = 0.95
            }
            // Cancel any existing timeout task
            dragTimeoutTask?.cancel()

            // Create a timeout task to restore state if drop is not completed
            let task = DispatchWorkItem {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    self.isDragging = false
                    self.scale = 1.0
                    self.isDropTarget = false
                }
            }
            dragTimeoutTask = task

            // Execute timeout after 0.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)

            // Create a simple drag preview with just the icon
            let provider = NSItemProvider(object: item.id.uuidString as NSString)

            // Set suggested name for better accessibility
            if item.getIcon() != nil {
                provider.suggestedName = item.name
            }

            return provider
        }
        .onDrop(of: [UTType.text], delegate: ItemDropDelegate(
            item: item,
            layer: layer,
            isDragging: $isDragging,
            isDropTarget: $isDropTarget,
            scale: $scale,
            dragTimeoutTask: $dragTimeoutTask
        ))
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: scale)
        .animation(.easeInOut(duration: 0.2), value: isDropTarget)
        .contextMenu {
            Button("编辑") {
                AddItemWindowManager.shared.showEditItemWindow(item: item)
            }
            Button("删除", role: .destructive) {
                DataManager.shared.deleteItem(item)
            }
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

// MARK: - Item Drop Delegate
struct ItemDropDelegate: SwiftUI.DropDelegate {
    let item: PanelItem
    let layer: PanelLayer
    @Binding var isDragging: Bool
    @Binding var isDropTarget: Bool
    @Binding var scale: CGFloat
    @Binding var dragTimeoutTask: DispatchWorkItem?

    @State private var hasSwapped = false

    func performDrop(info: DropInfo) -> Bool {
        // Cancel the timeout task since drop completed successfully
        dragTimeoutTask?.cancel()
        dragTimeoutTask = nil

        // Delay restoring the dragging state to allow swap animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                isDragging = false
                scale = 1.0
            }
        }

        // Immediately hide the drop target highlight
        withAnimation(.easeOut(duration: 0.15)) {
            isDropTarget = false
        }

        hasSwapped = false
        return true
    }

    func dropEntered(info: DropInfo) {
        // Visual feedback
        withAnimation(.easeInOut(duration: 0.15)) {
            isDropTarget = true
            scale = 1.05
        }

        // Prevent multiple swaps
        guard !hasSwapped else { return }

        // Get the dragged item ID
        guard let itemProviders = info.itemProviders(for: [UTType.text]).first else { return }

        itemProviders.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { (data, error) in
            guard let data = data as? Data,
                  let draggedIdString = String(data: data, encoding: .utf8),
                  let draggedId = UUID(uuidString: draggedIdString) else {
                return
            }

            DispatchQueue.main.async {
                // Find the dragged item and target item
                let items = DataManager.shared.getItems(for: layer)
                guard let draggedIndex = items.firstIndex(where: { $0.id == draggedId }),
                      let targetIndex = items.firstIndex(where: { $0.id == item.id }),
                      draggedIndex != targetIndex else {
                    return
                }

                // Perform the swap in DataManager
                hasSwapped = true
                DataManager.shared.swapItems(layer: layer, fromIndex: draggedIndex, toIndex: targetIndex)
            }
        }
    }

    func dropExited(info: DropInfo) {
        withAnimation(.easeOut(duration: 0.15)) {
            isDropTarget = false
            scale = 1.0
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
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


// MARK: - Group Name Editor
struct GroupNameEditorView: View {
    @Binding var groupName: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("设置分组名称")
                .font(.system(size: 12, weight: .medium))

            TextField("分组名称（留空则使用默认）", text: $groupName)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    onSave()
                }

            HStack {
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("保存") {
                    onSave()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let hidePanel = Notification.Name("hidePanel")
}
