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
    @ObservedObject var settingsManager = SettingsManager.shared
    @ObservedObject var contextDetector = ContextDetector.shared
    @State private var upperPage = 0
    @State private var lowerPage = 0

    var upperColumns: [GridItem] {
        let settings = settingsManager.settings
        return Array(repeating: GridItem(.fixed(70), spacing: settings.itemSpacing), count: settings.upperGridColumns)
    }

    var lowerColumns: [GridItem] {
        let settings = settingsManager.settings
        return Array(repeating: GridItem(.fixed(70), spacing: settings.itemSpacing), count: settings.lowerGridColumns)
    }

    var upperItemsPerPage: Int {
        settingsManager.settings.upperItemsPerPage
    }

    var lowerItemsPerPage: Int {
        settingsManager.settings.lowerItemsPerPage
    }

    var upperItems: [PanelItem] {
        dataManager.getItems(for: .upper)
    }

    var lowerItems: [PanelItem] {
        if let frontmostApp = currentFrontmostApp {
            let items = dataManager.getItemsForCurrentApp(bundleIdentifier: frontmostApp.bundleIdentifier)
            print("📱 Getting lower items for \(frontmostApp.appName) (\(frontmostApp.bundleIdentifier)): \(items.count) items")
            return items
        }
        print("⚠️ No bundle ID, returning empty lower items")
        return []
    }

    private var currentFrontmostApp: FrontmostAppInfo? {
        contextDetector.frontmostAppInfo
    }

    private var currentAppBundleId: String? {
        currentFrontmostApp?.bundleIdentifier
    }

    private var currentAppName: String {
        currentFrontmostApp?.appName ?? "当前应用"
    }

    private var lowerLayerEmptyMessage: String? {
        guard lowerItems.isEmpty else { return nil }

        if currentFrontmostApp == nil {
            return "暂未识别到当前应用，可点击空位手动添加项目。"
        }

        return "当前应用还没有专属项目，可点击空位添加。"
    }

    var upperPageCount: Int {
        max(1, Int(ceil(Double(max(upperItems.count, 1)) / Double(upperItemsPerPage))))
    }

    var lowerPageCount: Int {
        max(1, Int(ceil(Double(max(lowerItems.count, 1)) / Double(lowerItemsPerPage))))
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
                itemsPerPage: upperItemsPerPage,
                layer: .upper,
                pageScopeAppBundleId: nil,
                currentAppBundleId: nil,
                currentAppName: nil,
                title: "常用功能",
                columns: upperColumns,
                emptyMessage: nil
            )

            // Divider
            Divider()
                .padding(.horizontal, 20)

            // Lower grid - current app items
            LayerGridView(
                items: lowerItems,
                page: $lowerPage,
                itemsPerPage: lowerItemsPerPage,
                layer: .lower,
                pageScopeAppBundleId: currentAppBundleId,
                currentAppBundleId: currentAppBundleId,
                currentAppName: currentAppName,
                title: currentAppName,
                columns: lowerColumns,
                emptyMessage: lowerLayerEmptyMessage
            )
            .id("\(currentAppBundleId ?? "none")-\(lowerItems.count)")
        }
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 18))
        .onAppear {
            contextDetector.refreshCurrentApp()
        }
        .onReceive(NotificationCenter.default.publisher(for: .panelWillShow)) { _ in
            contextDetector.refreshCurrentApp()
        }
    }
}

// MARK: - Layer Grid View
struct LayerGridView: View {
    let items: [PanelItem]
    @Binding var page: Int
    let itemsPerPage: Int
    let layer: PanelLayer
    let pageScopeAppBundleId: String?
    let currentAppBundleId: String?
    let currentAppName: String?
    let title: String
    let columns: [GridItem]
    let emptyMessage: String?

    @ObservedObject private var dataManager = DataManager.shared
    @State private var showingGroupNameEditor = false
    @State private var editingGroupName = ""

    var pageCount: Int {
        dataManager.getPageCount(for: layer, appBundleIdentifier: pageScopeAppBundleId)
    }

    private func validatePage() {
        // If current page exceeds page count, go back to last valid page
        if page >= pageCount {
            page = max(0, pageCount - 1)
        }
    }

    var currentPageItems: [PanelItem] {
        let startOrder = page * itemsPerPage
        let endOrder = startOrder + itemsPerPage
        return items.filter { $0.order >= startOrder && $0.order < endOrder }
            .sorted { $0.order < $1.order }
    }

    // Always show 12 slots
    var slotsToShow: Int { itemsPerPage }

    var currentGroupName: String? {
        dataManager.getPageGroupName(layer: layer, page: page, appBundleIdentifier: pageScopeAppBundleId)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Title with page info
            HStack {
                LayerContextBadgeView(
                    layer: layer,
                    title: title,
                    currentAppName: currentAppName
                )
                .frame(width: 112, alignment: .leading)

                Spacer()

                HStack(spacing: 6) {
                    if page > 0 {
                        Button(action: {
                            let deletingPage = page
                            dataManager.deletePage(
                                layer: layer,
                                page: deletingPage,
                                itemsPerPage: itemsPerPage,
                                appBundleIdentifier: pageScopeAppBundleId
                            )
                            withAnimation {
                                page = max(0, deletingPage - 1)
                            }
                        }) {
                            Image(systemName: "minus")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary.opacity(0.5))
                                .frame(width: 14, height: 14)
                                .background(Circle().fill(Color.secondary.opacity(0.15)))
                        }
                        .buttonStyle(.plain)
                        .help("删除当前页")
                    }

                    if pageCount > 1 {
                        Text("\(page + 1)/\(pageCount)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.6))
                    }

                    Button(action: {
                        let newPage = dataManager.addPage(layer: layer, appBundleIdentifier: pageScopeAppBundleId)
                        dataManager.setPageGroup(
                            layer: layer,
                            page: newPage,
                            name: "面板#\(newPage + 1)",
                            appBundleIdentifier: pageScopeAppBundleId
                        )
                        withAnimation {
                            page = newPage
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.5))
                            .frame(width: 14, height: 14)
                            .background(Circle().fill(Color.secondary.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    .help("新建页面")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.04))
                .clipShape(Capsule())
                .frame(width: 112, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .onReceive(NotificationCenter.default.publisher(for: .scrollPreviousPage)) { notification in
                guard let userInfo = notification.userInfo,
                      let layerString = userInfo["layer"] as? String,
                      layerString == layer.rawValue else {
                    return
                }

                if page > 0 {
                    withAnimation {
                        page -= 1
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .scrollNextPage)) { notification in
                guard let userInfo = notification.userInfo,
                      let layerString = userInfo["layer"] as? String,
                      layerString == layer.rawValue else {
                    return
                }

                if page < pageCount - 1 {
                    withAnimation {
                        page += 1
                    }
                }
            }
            .overlay(alignment: .center) {
                GroupNameHeaderView(
                    groupName: currentGroupName,
                    onEdit: beginEditingGroupName
                )
                .popover(isPresented: $showingGroupNameEditor) {
                    GroupNameEditorView(
                        groupName: $editingGroupName,
                        onSave: saveGroupName,
                        onCancel: {
                            showingGroupNameEditor = false
                        }
                    )
                    .frame(width: 250, height: 100)
                }
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
                        currentAppName: currentAppName,
                        page: page
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPageItems.map { $0.id })

            if let emptyMessage, currentPageItems.isEmpty {
                EmptyStateHintView(message: emptyMessage)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)
            }

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

    private func beginEditingGroupName() {
        editingGroupName = currentGroupName ?? ""
        showingGroupNameEditor = true
    }

    private func saveGroupName() {
        let trimmedName = editingGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        dataManager.setPageGroup(
            layer: layer,
            page: page,
            name: trimmedName.isEmpty ? nil : trimmedName,
            appBundleIdentifier: pageScopeAppBundleId
        )
        showingGroupNameEditor = false
    }
}

// MARK: - Empty Slot
struct EmptySlotView: View {
    let layer: PanelLayer
    let currentAppBundleId: String?
    let currentAppName: String?
    let page: Int
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

            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: isHovered ? 20 : 16, weight: .medium))
                    .foregroundColor(.secondary.opacity(isHovered ? 0.6 : 0.35))

                if isHovered {
                    Text("添加")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
        }
        .frame(width: 70, height: 90)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            AddItemWindowManager.shared.showAddItemWindow(
                layer: layer,
                appBundleId: currentAppBundleId,
                appName: currentAppName,
                page: page
            )
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

struct GroupNameHeaderView: View {
    let groupName: String?
    let onEdit: () -> Void

    private var hasGroupName: Bool {
        !(groupName?.isEmpty ?? true)
    }

    var body: some View {
        HStack(spacing: 6) {
            if let groupName, !groupName.isEmpty {
                Text(groupName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.blue.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else {
                Text("命名分组")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Button(action: onEdit) {
                Image(systemName: hasGroupName ? "pencil" : "plus.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(hasGroupName ? .blue.opacity(0.8) : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(8)
        .frame(maxWidth: 180)
        .help(hasGroupName ? "编辑分组名称" : "为当前页命名")
    }
}

struct LayerContextBadgeView: View {
    let layer: PanelLayer
    let title: String
    let currentAppName: String?

    private var badgeTitle: String {
        if layer == .lower {
            return currentAppName ?? title
        }
        return title
    }

    private var iconName: String {
        layer == .lower ? "app.badge" : "square.grid.2x2"
    }

    var body: some View {
        Label(badgeTitle, systemImage: iconName)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

struct EmptyStateHintView: View {
    let message: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary.opacity(0.8))

            Text(message)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.035))
        .cornerRadius(10)
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
            appBundleIdentifier: item.appBundleIdentifier,
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
    let appBundleIdentifier: String?
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
                let items = DataManager.shared.getItems(for: layer, appBundleIdentifier: appBundleIdentifier)
                guard let draggedIndex = items.firstIndex(where: { $0.id == draggedId }),
                      let targetIndex = items.firstIndex(where: { $0.id == item.id }),
                      draggedIndex != targetIndex else {
                    return
                }

                // Perform the swap in DataManager
                hasSwapped = true
                DataManager.shared.swapItems(
                    layer: layer,
                    appBundleIdentifier: appBundleIdentifier,
                    fromIndex: draggedIndex,
                    toIndex: targetIndex
                )
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
