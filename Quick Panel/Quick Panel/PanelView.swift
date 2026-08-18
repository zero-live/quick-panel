//
//  PanelView.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Combine
import SwiftUI
import AppKit

enum PanelDragEdgeDirection: Equatable {
    case previous
    case next
}

struct PanelDragEdgeHint: Equatable {
    let context: PanelLayerDragContext
    let direction: PanelDragEdgeDirection
    let targetPage: Int
}

struct PanelLayerDragContext: Hashable {
    let layer: PanelLayer
    let appBundleIdentifier: String?
}

@MainActor
final class PanelGridDragVisualState: ObservableObject {
    static let shared = PanelGridDragVisualState()

    @Published private(set) var activeContext: PanelLayerDragContext?
    @Published private(set) var edgeHint: PanelDragEdgeHint?

    private init() {}

    func begin(context: PanelLayerDragContext) {
        guard activeContext != context else { return }
        activeContext = context
    }

    func updateEdgeHint(_ hint: PanelDragEdgeHint?) {
        guard edgeHint != hint else { return }
        edgeHint = hint
    }

    func end() {
        guard activeContext != nil || edgeHint != nil else { return }
        activeContext = nil
        edgeHint = nil
    }

    func isDragging(in context: PanelLayerDragContext) -> Bool {
        activeContext == context
    }
}

// MARK: - Vibrant Background
/// Renders the panel's translucent background.
///
/// `.nonactivatingPanel` never becomes key window, and SwiftUI's `.glassEffect()`
/// degrades to a flat gray blur in that state instead of real Liquid Glass. So for
/// the "liquid glass" styles this uses AppKit's `NSGlassEffectView` directly — the
/// same material the Dock and Control Center render with — which doesn't depend on
/// key-window state. Older `NSVisualEffectView` materials are kept as alternatives
/// forced to `.active` so they stay vibrant too.
struct PanelVibrantBackground: View {
    var style: PanelMaterialStyle
    var opacity: Double = 1
    var cornerRadius: CGFloat = 18

    var body: some View {
        if style.usesLiquidGlass {
            LiquidGlassBackgroundView(
                glassStyle: style.glassStyle,
                opacity: opacity,
                cornerRadius: cornerRadius
            )
        } else {
            VisualEffectBackgroundView(
                material: style.material,
                opacity: opacity,
                cornerRadius: cornerRadius
            )
        }
    }
}

struct PanelVibrantSurface: View {
    var style: PanelMaterialStyle
    var opacity: Double
    var cornerRadius: CGFloat

    private var usesLowOpacityReadabilityMode: Bool {
        opacity <= 0.45
    }

    private var readabilityBoost: Double {
        max(0, min(1, (0.5 - opacity) / 0.3))
    }

    private var borderColor: Color {
        if usesLowOpacityReadabilityMode {
            return Color.black.opacity(0.18 + 0.12 * readabilityBoost)
        }

        return style.usesLiquidGlass
            ? Color.white.opacity(0.25)
            : Color.primary.opacity(0.08)
    }

    var body: some View {
        ZStack {
            PanelVibrantBackground(
                style: style,
                opacity: opacity,
                cornerRadius: cornerRadius
            )

            // A neutral graphite wash reduces wallpaper detail without making
            // low-opacity glass look milky or changing its transparency setting.
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(white: 0.52).opacity(0.14 * readabilityBoost))
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(borderColor, lineWidth: usesLowOpacityReadabilityMode ? 0.9 : 0.75)
        }
        .allowsHitTesting(false)
    }
}

struct LiquidGlassBackgroundView: NSViewRepresentable {
    var glassStyle: NSGlassEffectView.Style
    var opacity: Double
    var cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.style = glassStyle
        view.alphaValue = opacity
        view.cornerRadius = cornerRadius
        view.clipsToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSGlassEffectView, context: Context) {
        nsView.style = glassStyle
        nsView.alphaValue = opacity
        nsView.cornerRadius = cornerRadius
        nsView.clipsToBounds = true
    }
}

struct VisualEffectBackgroundView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var opacity: Double
    var cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = true
        view.alphaValue = opacity
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.state = .active
        nsView.alphaValue = opacity
        nsView.layer?.cornerRadius = cornerRadius
    }
}

struct PanelView: View {
    @Environment(\.colorScheme) private var systemColorScheme
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var settingsManager = SettingsManager.shared
    @ObservedObject var contextDetector = ContextDetector.shared
    @ObservedObject private var layoutManager = PanelLayoutManager.shared
    @State private var upperPage = 0
    @State private var lowerPagesByApp: [String: Int] = SettingsManager.shared.settings.lowerPageMemory

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
            return items
        }
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

    private var usesLowOpacityReadabilityMode: Bool {
        settingsManager.settings.panelOpacity <= 0.45
    }

    private var contentColorScheme: ColorScheme {
        usesLowOpacityReadabilityMode ? .light : systemColorScheme
    }

    private var readabilityBoost: Double {
        let opacity = settingsManager.settings.panelOpacity
        return max(0, min(1, (0.5 - opacity) / 0.3))
    }

    private var resolvedLowerPageScopeKey: String {
        currentAppBundleId ?? "__none__"
    }

    private var lowerPageBinding: Binding<Int> {
        Binding(
            get: {
                lowerPagesByApp[resolvedLowerPageScopeKey] ?? 0
            },
            set: { newValue in
                updateRememberedLowerPage(max(0, newValue), for: resolvedLowerPageScopeKey)
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle at the top
            DragHandleView(scale: layoutManager.metrics.scale)
                .frame(height: layoutManager.metrics.dragHandleHeight)

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
                emptyMessage: nil
            )

            // Divider
            Divider()
                .background(Color.secondary.opacity(0.2))
                .frame(height: layoutManager.metrics.dividerThickness)
                .padding(.horizontal, layoutManager.metrics.horizontalPadding)
                .padding(.vertical, layoutManager.metrics.dividerVerticalPadding)

            // Lower grid - current app items
            LayerGridView(
                items: lowerItems,
                page: lowerPageBinding,
                itemsPerPage: lowerItemsPerPage,
                layer: .lower,
                pageScopeAppBundleId: currentAppBundleId,
                currentAppBundleId: currentAppBundleId,
                currentAppName: currentAppName,
                title: currentAppName,
                emptyMessage: lowerLayerEmptyMessage
            )
            .id("\(currentAppBundleId ?? "none")-\(lowerItems.count)")
        }
        .coordinateSpace(name: "panelDragSpace")
        .environment(\.colorScheme, contentColorScheme)
        .shadow(
            color: Color(white: 0.48).opacity(0.46 * readabilityBoost),
            radius: 0.9,
            x: 0,
            y: 0.5
        )
        .background(
            PanelVibrantSurface(
                style: settingsManager.settings.panelMaterialStyle,
                opacity: settingsManager.settings.panelOpacity,
                cornerRadius: 18 * layoutManager.metrics.scale
            )
        )
        .onAppear {
            lowerPagesByApp = settingsManager.settings.lowerPageMemory
            contextDetector.refreshCurrentApp()
            syncLowerPageState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .panelWillShow)) { _ in
            contextDetector.refreshCurrentApp()
            syncLowerPageState()
        }
        .onChange(of: currentAppBundleId) { _, _ in
            syncLowerPageState()
        }
        .onChange(of: lowerItems.map(\.id)) { _, _ in
            syncLowerPageState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsDidChange)) { _ in
            lowerPagesByApp = settingsManager.settings.lowerPageMemory
            syncLowerPageState()
        }
    }

    private func syncLowerPageState() {
        guard let currentAppBundleId else {
            if lowerPagesByApp["__none__"] != nil {
                updateRememberedLowerPage(nil, for: "__none__")
            }
            return
        }

        let pageCount = dataManager.getPageCount(for: .lower, appBundleIdentifier: currentAppBundleId)
        let currentPage = lowerPagesByApp[currentAppBundleId] ?? 0
        let validatedPage = min(max(0, currentPage), max(0, pageCount - 1))

        if validatedPage != currentPage {
            updateRememberedLowerPage(validatedPage, for: currentAppBundleId)
        } else if lowerPagesByApp[currentAppBundleId] == nil {
            updateRememberedLowerPage(0, for: currentAppBundleId)
        }
    }

    private func updateRememberedLowerPage(_ page: Int?, for scopeKey: String) {
        var updatedMemory = lowerPagesByApp

        if let page {
            updatedMemory[scopeKey] = max(0, page)
        } else {
            updatedMemory.removeValue(forKey: scopeKey)
        }

        guard updatedMemory != lowerPagesByApp else { return }
        lowerPagesByApp = updatedMemory

        settingsManager.persistLowerPageMemory(updatedMemory)
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
    let emptyMessage: String?

    @ObservedObject private var dataManager = DataManager.shared
    @ObservedObject private var settingsManager = SettingsManager.shared
    @ObservedObject private var layoutManager = PanelLayoutManager.shared
    @State private var showingGroupNameEditor = false
    @State private var editingGroupName = ""
    @State private var pageMovedForward = true
    @State private var isDeletePageHovered = false
    @State private var isAddPageHovered = false
    @State private var showingDeletePageConfirm = false

    private var layerHeight: CGFloat {
        layoutManager.metrics.layerHeight(for: layer, settings: settingsManager.settings)
    }

    private var layerDragContext: PanelLayerDragContext {
        PanelLayerDragContext(layer: layer, appBundleIdentifier: pageScopeAppBundleId)
    }

    private var gridColumns: Int {
        settingsManager.settings.gridColumns(for: layer)
    }

    private var gridRows: Int {
        settingsManager.settings.gridRows(for: layer)
    }

    private var cellSize: CGSize {
        layoutManager.metrics.cellSize
    }

    private var gridSpacing: CGFloat {
        layoutManager.metrics.itemSpacing
    }

    private var gridContentSize: CGSize {
        CGSize(
            width: CGFloat(gridColumns) * cellSize.width + CGFloat(max(0, gridColumns - 1)) * gridSpacing,
            height: CGFloat(gridRows) * cellSize.height + CGFloat(max(0, gridRows - 1)) * gridSpacing
        )
    }

    var pageCount: Int {
        dataManager.getPageCount(for: layer, appBundleIdentifier: pageScopeAppBundleId)
    }

    private func validatePage() {
        // If current page exceeds page count, go back to last valid page
        if page >= pageCount {
            page = max(0, pageCount - 1)
        }
    }

    private func deleteCurrentPage() {
        let deletingPage = page
        dataManager.deletePage(
            layer: layer,
            page: deletingPage,
            appBundleIdentifier: pageScopeAppBundleId
        )
        goToPage(max(0, deletingPage - 1))
    }

    private func goToPage(_ newPage: Int) {
        pageMovedForward = newPage >= page
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            page = newPage
        }
    }

    var currentPageItems: [PanelItem] {
        items
            .filter { $0.page == page }
            .sorted {
                if $0.slot == $1.slot {
                    return $0.id.uuidString < $1.id.uuidString
                }
                return $0.slot < $1.slot
            }
    }

    private var currentPageItemsBySlot: [Int: PanelItem] {
        return Dictionary(
            uniqueKeysWithValues: currentPageItems.compactMap { item in
                guard item.slot >= 0, item.slot < itemsPerPage else { return nil }
                return (item.slot, item)
            }
        )
    }

    // Always show 12 slots
    var slotsToShow: Int { itemsPerPage }

    var currentGroupName: String? {
        dataManager.getPageGroupName(layer: layer, page: page, appBundleIdentifier: pageScopeAppBundleId)
    }

    var body: some View {
        VStack(spacing: 4 * layoutManager.metrics.scale) {
            // Title with page info
            HStack {
                LayerContextBadgeView(
                    layer: layer,
                    title: title,
                    currentAppName: currentAppName,
                    scale: layoutManager.metrics.scale
                )
                .frame(width: 112 * layoutManager.metrics.scale, alignment: .leading)

                Spacer()

                HStack(spacing: 6 * layoutManager.metrics.scale) {
                    if page > 0 {
                        Button(action: {
                            if currentPageItems.isEmpty {
                                deleteCurrentPage()
                            } else {
                                showingDeletePageConfirm = true
                            }
                        }) {
                            Image(systemName: "minus")
                                .font(.system(size: 9 * layoutManager.metrics.scale, weight: .bold))
                                .foregroundColor(.secondary.opacity(isDeletePageHovered ? 0.8 : 0.5))
                                .frame(width: 14 * layoutManager.metrics.scale, height: 14 * layoutManager.metrics.scale)
                                .background(Circle().fill(Color.secondary.opacity(isDeletePageHovered ? 0.25 : 0.15)))
                                .scaleEffect(isDeletePageHovered ? 1.1 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .help("删除当前页")
                        .onHover { hovering in
                            withAnimation(.easeOut(duration: 0.12)) {
                                isDeletePageHovered = hovering
                            }
                        }
                        .confirmationDialog(
                            "确定删除此页吗？",
                            isPresented: $showingDeletePageConfirm,
                            titleVisibility: .visible
                        ) {
                            Button("删除该页及其中的项目", role: .destructive) {
                                deleteCurrentPage()
                            }
                            Button("取消", role: .cancel) {}
                        } message: {
                            Text("此页面上的 \(currentPageItems.count) 个项目将一并被删除，且无法撤销。")
                        }
                    }

                    if pageCount > 1 {
                        Text("\(page + 1)/\(pageCount)")
                            .font(.system(size: 10 * layoutManager.metrics.scale))
                            .foregroundColor(.secondary.opacity(0.6))
                    }

                    Button(action: {
                        let nextPage = pageCount
                        let newPage = dataManager.addPage(
                            layer: layer,
                            appBundleIdentifier: pageScopeAppBundleId,
                            groupName: "面板#\(nextPage + 1)"
                        )
                        goToPage(newPage)
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 9 * layoutManager.metrics.scale, weight: .bold))
                            .foregroundColor(.secondary.opacity(isAddPageHovered ? 0.8 : 0.5))
                            .frame(width: 14 * layoutManager.metrics.scale, height: 14 * layoutManager.metrics.scale)
                            .background(Circle().fill(Color.secondary.opacity(isAddPageHovered ? 0.25 : 0.15)))
                            .scaleEffect(isAddPageHovered ? 1.1 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .help("新建页面")
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: 0.12)) {
                            isAddPageHovered = hovering
                        }
                    }
                }
                .padding(.horizontal, 8 * layoutManager.metrics.scale)
                .padding(.vertical, 5 * layoutManager.metrics.scale)
                .background(Color.primary.opacity(0.04))
                .clipShape(Capsule())
                .frame(width: 112 * layoutManager.metrics.scale, alignment: .trailing)
            }
            .padding(.horizontal, layoutManager.metrics.horizontalPadding)
            .padding(.top, 4 * layoutManager.metrics.scale)
            .onReceive(NotificationCenter.default.publisher(for: .scrollPreviousPage)) { notification in
                guard let userInfo = notification.userInfo,
                      let layerString = userInfo["layer"] as? String,
                      layerString == layer.rawValue else {
                    return
                }

                if page > 0 {
                    goToPage(page - 1)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .scrollNextPage)) { notification in
                guard let userInfo = notification.userInfo,
                      let layerString = userInfo["layer"] as? String,
                      layerString == layer.rawValue else {
                    return
                }

                if page < pageCount - 1 {
                    goToPage(page + 1)
                }
            }
            .overlay(alignment: .center) {
                GroupNameHeaderView(
                    groupName: currentGroupName,
                    onEdit: beginEditingGroupName,
                    scale: layoutManager.metrics.scale
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

            DesktopGridView(
                itemsBySlot: currentPageItemsBySlot,
                layer: layer,
                pageScopeAppBundleId: pageScopeAppBundleId,
                currentAppBundleId: currentAppBundleId,
                currentAppName: currentAppName,
                page: page,
                pageCount: pageCount,
                columns: gridColumns,
                rows: gridRows,
                cellSize: cellSize,
                spacing: gridSpacing,
                visualScale: layoutManager.metrics.scale
            )
            .id(page)
            .frame(width: gridContentSize.width, height: gridContentSize.height)
            .padding(.horizontal, layoutManager.metrics.horizontalPadding)
            .padding(.bottom, 6 * layoutManager.metrics.scale)
            .transition(.asymmetric(
                insertion: .move(edge: pageMovedForward ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: pageMovedForward ? .leading : .trailing).combined(with: .opacity)
            ))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: page)

            if let emptyMessage, currentPageItems.isEmpty {
                EmptyStateHintView(message: emptyMessage, scale: layoutManager.metrics.scale)
                    .padding(.horizontal, layoutManager.metrics.horizontalPadding)
                    .padding(.bottom, 2 * layoutManager.metrics.scale)
            }

            if pageCount > 1 {
                HStack(spacing: 8 * layoutManager.metrics.scale) {
                    PageChevronButton(
                        systemName: "chevron.up",
                        isEnabled: page > 0,
                        helpText: "上一页（也可将鼠标悬停在此层区域滚动滚轮）",
                        scale: layoutManager.metrics.scale
                    ) {
                        if page > 0 {
                            goToPage(page - 1)
                        }
                    }

                    HStack(spacing: 6 * layoutManager.metrics.scale) {
                        ForEach(0..<pageCount, id: \.self) { index in
                            PageIndicatorDot(
                                index: index,
                                currentPage: $page,
                                scale: layoutManager.metrics.scale
                            )
                            .frame(width: 14 * layoutManager.metrics.scale, height: 14 * layoutManager.metrics.scale)
                                .onTapGesture {
                                    goToPage(index)
                                }
                        }
                    }

                    PageChevronButton(
                        systemName: "chevron.down",
                        isEnabled: page < pageCount - 1,
                        helpText: "下一页（也可将鼠标悬停在此层区域滚动滚轮）",
                        scale: layoutManager.metrics.scale
                    ) {
                        if page < pageCount - 1 {
                            goToPage(page + 1)
                        }
                    }
                }
                .padding(.bottom, 2 * layoutManager.metrics.scale)
            }
        }
        .frame(height: layerHeight, alignment: .top)
        .clipped()
        .overlay {
            LayerEdgePageSwitchHint(
                context: layerDragContext,
                currentPage: page,
                pageCount: pageCount,
                scale: layoutManager.metrics.scale
            )
            .allowsHitTesting(false)
        }
        .onReceive(NotificationCenter.default.publisher(for: .panelDragRequestPageSwitch)) { notification in
            guard let userInfo = notification.userInfo,
                  let layerString = userInfo["layer"] as? String,
                  layerString == layer.rawValue,
                  let requestedPage = userInfo["page"] as? Int else {
                return
            }

            let requestedBundleId = userInfo["appBundleIdentifier"] as? String
            guard requestedBundleId == pageScopeAppBundleId,
                  requestedPage >= 0,
                  requestedPage < pageCount,
                  requestedPage != page else {
                return
            }

            pageMovedForward = requestedPage >= page
            withAnimation(.easeInOut(duration: 0.18)) {
                page = requestedPage
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

// MARK: - Desktop Grid View
// MARK: - Edge Page Switch Hint
struct LayerEdgePageSwitchHint: View {
    let context: PanelLayerDragContext
    let currentPage: Int
    let pageCount: Int
    let scale: CGFloat
    @ObservedObject private var gridDragVisualState = PanelGridDragVisualState.shared

    private var hint: PanelDragEdgeHint? {
        guard let edgeHint = gridDragVisualState.edgeHint,
              edgeHint.context == context else { return nil }
        return edgeHint
    }

    private var canSwitchPrevious: Bool {
        pageCount > 1 && currentPage > 0
    }

    private var canSwitchNext: Bool {
        pageCount > 1 && currentPage < pageCount - 1
    }

    private var shouldShowPassiveHints: Bool {
        pageCount > 1 &&
            gridDragVisualState.isDragging(in: context)
    }

    var body: some View {
        HStack {
            EdgePageSwitchBar(
                direction: .previous,
                isActive: hint?.direction == .previous,
                isVisible: shouldShowPassiveHints && canSwitchPrevious,
                scale: scale
            )

            Spacer()

            EdgePageSwitchBar(
                direction: .next,
                isActive: hint?.direction == .next,
                isVisible: shouldShowPassiveHints && canSwitchNext,
                scale: scale
            )
        }
        .padding(.horizontal, 6 * scale)
        .padding(.vertical, 28 * scale)
        .animation(.spring(response: 0.22, dampingFraction: 0.75), value: hint)
        .animation(.easeInOut(duration: 0.16), value: shouldShowPassiveHints)
    }
}

struct EdgePageSwitchBar: View {
    let direction: PanelDragEdgeDirection
    let isActive: Bool
    let isVisible: Bool
    let scale: CGFloat

    private var iconName: String {
        direction == .previous ? "chevron.left" : "chevron.right"
    }

    var body: some View {
        VStack(spacing: 8 * scale) {
            Image(systemName: iconName)
                .font(.system(size: 12 * scale, weight: .bold))
                .foregroundColor(.white.opacity(isActive ? 0.98 : 0.72))

            RoundedRectangle(cornerRadius: 999)
                .fill(Color.white.opacity(isActive ? 0.86 : 0.42))
                .frame(width: 3 * scale, height: (isActive ? 72 : 46) * scale)
        }
        .frame(width: (isActive ? 24 : 18) * scale)
        .frame(maxHeight: .infinity)
        .background(
            Capsule()
                .fill(Color.accentColor.opacity(isActive ? 0.72 : 0.26))
                .shadow(color: Color.accentColor.opacity(isActive ? 0.32 : 0.12), radius: (isActive ? 12 : 5) * scale, x: 0, y: 0)
        )
        .scaleEffect(isActive ? 1.05 : 1.0)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.18), value: isActive)
        .animation(.easeInOut(duration: 0.15), value: isVisible)
    }
}

// MARK: - Drag Handle
struct DragHandleView: View {
    let scale: CGFloat
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 4 * scale) {
            Spacer()
            // Three dots indicator
            HStack(spacing: 4 * scale) {
                ForEach(0..<3) { _ in
                    Circle()
                        .fill(Color.secondary.opacity(isHovered ? 0.7 : 0.6))
                        .frame(width: 5 * scale, height: 5 * scale)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct GroupNameHeaderView: View {
    let groupName: String?
    let onEdit: () -> Void
    let scale: CGFloat
    @State private var isHovered = false

    private var hasGroupName: Bool {
        !(groupName?.isEmpty ?? true)
    }

    var body: some View {
        HStack(spacing: 6 * scale) {
            if let groupName, !groupName.isEmpty {
                Text(groupName)
                    .font(.system(size: 11 * scale, weight: .semibold))
                    .foregroundColor(.blue.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else {
                Text("命名分组")
                    .font(.system(size: 11 * scale, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Button(action: onEdit) {
                Image(systemName: hasGroupName ? "pencil" : "plus.circle")
                    .font(.system(size: 11 * scale, weight: .semibold))
                    .foregroundColor(hasGroupName ? .blue.opacity(0.8) : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8 * scale)
        .padding(.vertical, 4 * scale)
        .background(Color.primary.opacity(isHovered ? 0.08 : 0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 8 * scale)
                .stroke(Color.secondary.opacity(0.2), lineWidth: max(0.5, 0.5 * scale))
        )
        .cornerRadius(8 * scale)
        .frame(maxWidth: 180 * scale)
        .help(hasGroupName ? "编辑分组名称" : "为当前页命名")
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onTapGesture {
            onEdit()
        }
    }
}

struct LayerContextBadgeView: View {
    let layer: PanelLayer
    let title: String
    let currentAppName: String?
    let scale: CGFloat

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
            .font(.system(size: 11 * scale, weight: .medium))
            .foregroundColor(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

struct EmptyStateHintView: View {
    let message: String
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 6 * scale) {
            Image(systemName: "info.circle")
                .font(.system(size: 11 * scale, weight: .medium))
                .foregroundColor(.secondary.opacity(0.8))

            Text(message)
                .font(.system(size: 11 * scale))
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10 * scale)
        .padding(.vertical, 6 * scale)
        .background(Color.primary.opacity(0.035))
        .cornerRadius(10 * scale)
    }
}

// MARK: - Item Content
struct ItemContentView: View {
    let item: PanelItem
    let isHovered: Bool
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 6 * scale) {
            if let icon = item.getIcon() {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48 * scale, height: 48 * scale)
                    .background(
                        RoundedRectangle(cornerRadius: 10 * scale)
                            .fill(isHovered ? Color.primary.opacity(0.1) : Color.clear)
                    )
            }

            Text(item.name)
                .font(.system(size: 11 * scale))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(.primary)
                .frame(maxWidth: 70 * scale)
                .help(item.name)
        }
    }
}

// MARK: - Page Chevron Button
struct PageChevronButton: View {
    let systemName: String
    let isEnabled: Bool
    let helpText: String
    let scale: CGFloat
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 8 * scale, weight: .bold))
            .foregroundColor(.secondary.opacity(isEnabled ? (isHovered ? 0.85 : 0.55) : 0.15))
            .frame(width: 16 * scale, height: 16 * scale)
            .background(
                Circle().fill(Color.secondary.opacity(isEnabled && isHovered ? 0.15 : 0))
            )
            .scaleEffect(isEnabled && isHovered ? 1.15 : 1.0)
            .contentShape(Rectangle())
            .onTapGesture {
                action()
            }
            .help(helpText)
            .onHover { hovering in
                guard isEnabled else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    isHovered = hovering
                }
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

// MARK: - Page Indicator Dot
struct PageIndicatorDot: View {
    let index: Int
    @Binding var currentPage: Int
    let scale: CGFloat
    @State private var isHovered = false

    private var isCurrent: Bool {
        currentPage == index
    }

    var body: some View {
        Circle()
            .fill(isCurrent ? Color.accentColor : Color.secondary.opacity(isHovered ? 0.75 : 0.5))
            .frame(
                width: (isCurrent ? 9 : (isHovered ? 8 : 7)) * scale,
                height: (isCurrent ? 9 : (isHovered ? 8 : 7)) * scale
            )
            .contentShape(Circle())
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
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
    static let panelDragRequestPageSwitch = Notification.Name("panelDragRequestPageSwitch")
}
