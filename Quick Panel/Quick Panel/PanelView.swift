//
//  PanelView.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Combine
import SwiftUI
import AppKit

enum PanelDropTargetKind: Hashable {
    case slot
    case pageIndicator
}

enum PanelDragEdgeDirection: Equatable {
    case previous
    case next
}

struct PanelDragEdgeHint: Equatable {
    let context: PanelLayerDragContext
    let direction: PanelDragEdgeDirection
    let targetPage: Int
}

struct PanelDropTarget: Hashable {
    let layer: PanelLayer
    let appBundleIdentifier: String?
    let page: Int
    let slot: Int
    let itemsPerPage: Int
    let kind: PanelDropTargetKind
}

struct PanelLayerDragContext: Hashable {
    let layer: PanelLayer
    let appBundleIdentifier: String?
}

struct PanelLayerFrameInfo {
    var frame: CGRect
    var currentPage: Int
    var pageCount: Int
}

struct PanelGridMetrics: Equatable {
    let frame: CGRect
    let columns: Int
    let rows: Int
    let cellSize: CGSize
    let spacing: CGFloat

    var itemsPerPage: Int {
        columns * rows
    }

    var contentSize: CGSize {
        CGSize(
            width: CGFloat(columns) * cellSize.width + CGFloat(max(0, columns - 1)) * spacing,
            height: CGFloat(rows) * cellSize.height + CGFloat(max(0, rows - 1)) * spacing
        )
    }

    func localFrame(for slot: Int) -> CGRect {
        guard slot >= 0, slot < itemsPerPage, columns > 0 else { return .zero }

        let column = slot % columns
        let row = slot / columns
        return CGRect(
            x: CGFloat(column) * (cellSize.width + spacing),
            y: CGFloat(row) * (cellSize.height + spacing),
            width: cellSize.width,
            height: cellSize.height
        )
    }

    func localPosition(for slot: Int) -> CGPoint {
        let slotFrame = localFrame(for: slot)
        return CGPoint(x: slotFrame.midX, y: slotFrame.midY)
    }

    func frame(for slot: Int) -> CGRect {
        localFrame(for: slot).offsetBy(dx: frame.minX, dy: frame.minY)
    }

    func slot(at point: CGPoint, hitSlop: CGFloat) -> Int? {
        guard frame.insetBy(dx: -hitSlop, dy: -hitSlop).contains(point) else {
            return nil
        }

        let localPoint = CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
        var nearestSlot: Int?
        var nearestDistance = CGFloat.greatestFiniteMagnitude

        for slot in 0..<itemsPerPage {
            let slotFrame = localFrame(for: slot).insetBy(dx: -hitSlop, dy: -hitSlop)
            guard slotFrame.contains(localPoint) else { continue }

            let center = localPosition(for: slot)
            let deltaX = localPoint.x - center.x
            let deltaY = localPoint.y - center.y
            let distance = deltaX * deltaX + deltaY * deltaY
            if distance < nearestDistance {
                nearestDistance = distance
                nearestSlot = slot
            }
        }

        return nearestSlot
    }
}

struct PanelDragState: Equatable {
    let itemId: UUID
    let layer: PanelLayer
    let appBundleIdentifier: String?
}

struct PanelDragSession {
    let item: PanelItem
    let state: PanelDragState
    var location: CGPoint
}

@MainActor
final class PanelDragManager: ObservableObject {
    static let shared = PanelDragManager()

    @Published private(set) var session: PanelDragSession?
    @Published private(set) var currentTargetFrame: CGRect?
    @Published private(set) var edgeHint: PanelDragEdgeHint?
    @Published private(set) var previewItemsByContext: [PanelLayerDragContext: [PanelItem]] = [:]

    private var targetFrames: [PanelDropTarget: CGRect] = [:]
    private var layerFrames: [PanelLayerDragContext: PanelLayerFrameInfo] = [:]
    private var gridMetricsByContext: [PanelLayerDragContext: PanelGridMetrics] = [:]
    private var baseItemsByContext: [PanelLayerDragContext: [PanelItem]] = [:]
    private var currentTarget: PanelDropTarget?
    private var localMouseMonitor: Any?
    private var pendingPageSwitch: DispatchWorkItem?
    private var pendingPageSwitchTarget: PanelDropTarget?
    private var edgeSwitchLock: PanelDragEdgeDirection?
    private weak var dragWindow: NSWindow?

    private let edgeSwitchInset: CGFloat = 76
    private let edgeSwitchOuterTolerance: CGFloat = 28
    private let edgeSwitchVerticalTolerance: CGFloat = 10
    private let targetHitSlop: CGFloat = 8
    private let edgeSwitchReleaseInset: CGFloat = 112
    private let pageSwitchDelay: TimeInterval = 0.38

    private init() {}

    func beginDrag(item: PanelItem, appBundleIdentifier: String?, at location: CGPoint) {
        let state = PanelDragState(
            itemId: item.id,
            layer: item.layer,
            appBundleIdentifier: appBundleIdentifier
        )
        session = PanelDragSession(item: item, state: state, location: location)
        currentTarget = nil
        currentTargetFrame = nil
        edgeHint = nil
        edgeSwitchLock = nil
        dragWindow = NSApp.windows.first { $0.isVisible && $0 is NSPanel } ?? NSApp.keyWindow
        installLocalMouseMonitor()
        updateDrag(at: location)
    }

    func updateDrag(at point: CGPoint) {
        guard var session else { return }
        session.location = point
        self.session = session

        let target = dropTarget(at: point, for: session)
        let targetFrame = target.flatMap { targetFrames[$0] }

        if target != currentTarget || targetFrame != currentTargetFrame {
            currentTarget = target
            currentTargetFrame = targetFrame
            handleTargetChange(target)
        }

        updatePreviewLayout(for: target)
        scheduleEdgePageSwitchIfNeeded(at: point)
    }

    func endDrag() {
        guard let session else {
            reset()
            return
        }

        defer { reset() }

        guard let currentTarget,
              currentTarget.layer == session.state.layer,
              currentTarget.appBundleIdentifier == session.state.appBundleIdentifier else {
            return
        }

        let context = PanelLayerDragContext(
            layer: currentTarget.layer,
            appBundleIdentifier: currentTarget.appBundleIdentifier
        )

        if let previewItems = previewItemsByContext[context] {
            DataManager.shared.replaceItems(
                for: currentTarget.layer,
                appBundleIdentifier: currentTarget.appBundleIdentifier,
                with: previewItems
            )
        } else {
            DataManager.shared.moveItem(
                id: session.state.itemId,
                layer: currentTarget.layer,
                appBundleIdentifier: currentTarget.appBundleIdentifier,
                toPage: currentTarget.page,
                slotIndex: currentTarget.slot,
                itemsPerPage: currentTarget.itemsPerPage
            )
        }
    }

    func cancelDrag() {
        reset()
    }

    func registerTarget(_ target: PanelDropTarget, frame: CGRect) {
        guard !frame.isEmpty else { return }
        targetFrames[target] = frame
    }

    func registerLayerFrame(context: PanelLayerDragContext, frame: CGRect, currentPage: Int, pageCount: Int) {
        guard !frame.isEmpty else { return }
        layerFrames[context] = PanelLayerFrameInfo(
            frame: frame,
            currentPage: currentPage,
            pageCount: pageCount
        )
    }

    func registerGridMetrics(context: PanelLayerDragContext, metrics: PanelGridMetrics) {
        guard !metrics.frame.isEmpty else { return }
        gridMetricsByContext[context] = metrics
    }

    func unregisterGridMetrics(context: PanelLayerDragContext) {
        gridMetricsByContext.removeValue(forKey: context)
    }

    func displayedItems(for context: PanelLayerDragContext, sourceItems: [PanelItem]) -> [PanelItem] {
        previewItemsByContext[context] ?? sourceItems
    }

    func unregisterLayerFrame(context: PanelLayerDragContext) {
        layerFrames.removeValue(forKey: context)
    }

    func unregisterTarget(_ target: PanelDropTarget) {
        targetFrames.removeValue(forKey: target)
    }

    func unregisterSlotTargets(layer: PanelLayer, appBundleIdentifier: String?) {
        targetFrames = targetFrames.filter { target, _ in
            !(target.layer == layer &&
              target.appBundleIdentifier == appBundleIdentifier &&
              target.kind == .slot)
        }

        if currentTarget?.layer == layer,
           currentTarget?.appBundleIdentifier == appBundleIdentifier,
           currentTarget?.kind == .slot {
            currentTarget = nil
            currentTargetFrame = nil
        }
    }

    func isHovered(_ target: PanelDropTarget) -> Bool {
        currentTarget == target
    }

    func isDragging(in context: PanelLayerDragContext) -> Bool {
        guard let session else { return false }
        return session.state.layer == context.layer &&
            session.state.appBundleIdentifier == context.appBundleIdentifier
    }

    private func installLocalMouseMonitor() {
        guard localMouseMonitor == nil else { return }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] event in
            guard let self else { return event }

            Task { @MainActor in
                guard self.session != nil else { return }

                switch event.type {
                case .leftMouseDragged:
                    self.updateDrag(at: self.localPoint(from: event))
                case .leftMouseUp:
                    self.updateDrag(at: self.localPoint(from: event))
                    self.endDrag()
                default:
                    break
                }
            }

            return event
        }
    }

    private func localPoint(from event: NSEvent) -> CGPoint {
        let window = dragWindow ?? event.window ?? NSApp.keyWindow
        guard let window else { return .zero }

        let screenPoint = NSEvent.mouseLocation
        let frame = window.frame
        return CGPoint(
            x: screenPoint.x - frame.minX,
            y: frame.maxY - screenPoint.y
        )
    }

    private func handleTargetChange(_ target: PanelDropTarget?) {
        guard let target, target.kind == .pageIndicator else { return }
        requestPageSwitch(target)
    }

    private func dropTarget(at point: CGPoint, for session: PanelDragSession) -> PanelDropTarget? {
        let context = PanelLayerDragContext(
            layer: session.state.layer,
            appBundleIdentifier: session.state.appBundleIdentifier
        )
        let currentPage = layerFrames[context]?.currentPage

        if let metrics = gridMetricsByContext[context],
           let currentPage,
           let slot = metrics.slot(at: point, hitSlop: targetHitSlop) {
            return PanelDropTarget(
                layer: context.layer,
                appBundleIdentifier: context.appBundleIdentifier,
                page: currentPage,
                slot: slot,
                itemsPerPage: metrics.itemsPerPage,
                kind: .slot
            )
        }

        let candidates = targetFrames.compactMap { target, frame -> (target: PanelDropTarget, frame: CGRect, exactHit: Bool, distance: CGFloat)? in
            guard target.layer == session.state.layer,
                  target.appBundleIdentifier == session.state.appBundleIdentifier else {
                return nil
            }

            let expandedFrame = frame.insetBy(dx: -targetHitSlop, dy: -targetHitSlop)
            guard expandedFrame.contains(point) else { return nil }

            let deltaX = point.x - frame.midX
            let deltaY = point.y - frame.midY
            return (
                target: target,
                frame: frame,
                exactHit: frame.contains(point),
                distance: deltaX * deltaX + deltaY * deltaY
            )
        }

        return candidates.sorted { lhs, rhs in
            if lhs.target.kind != rhs.target.kind {
                return lhs.target.kind == .slot
            }

            if let currentPage, lhs.target.page != rhs.target.page {
                if lhs.target.page == currentPage { return true }
                if rhs.target.page == currentPage { return false }
            }

            if lhs.exactHit != rhs.exactHit {
                return lhs.exactHit
            }

            return lhs.distance < rhs.distance
        }
        .first?
        .target
    }

    private func updatePreviewLayout(for target: PanelDropTarget?) {
        guard let session,
              let target,
              target.kind == .slot,
              target.layer == session.state.layer,
              target.appBundleIdentifier == session.state.appBundleIdentifier else {
            return
        }

        let context = PanelLayerDragContext(
            layer: session.state.layer,
            appBundleIdentifier: session.state.appBundleIdentifier
        )

        let baseItems: [PanelItem]
        if let cachedItems = baseItemsByContext[context] {
            baseItems = cachedItems
        } else {
            let scopedItems = DataManager.shared.getItems(for: context.layer, appBundleIdentifier: context.appBundleIdentifier)
            baseItemsByContext[context] = scopedItems
            baseItems = scopedItems
        }

        let previewItems = previewLayoutItems(
            baseItems,
            movingItemId: session.state.itemId,
            targetPage: target.page,
            targetSlot: target.slot,
            itemsPerPage: target.itemsPerPage
        )

        if previewItemsByContext[context]?.map(layoutSignature) != previewItems.map(layoutSignature) {
            previewItemsByContext[context] = previewItems
        }
    }

    private func previewLayoutItems(_ sourceItems: [PanelItem], movingItemId: UUID, targetPage: Int, targetSlot: Int, itemsPerPage: Int) -> [PanelItem] {
        guard itemsPerPage > 0,
              let movingItem = sourceItems.first(where: { $0.id == movingItemId }) else {
            return sourceItems
        }

        let targetLinearIndex = max(0, targetPage) * itemsPerPage + min(max(0, targetSlot), itemsPerPage - 1)
        var resultItems = sourceItems
        var occupiedIndexes: [Int: Int] = [:]

        for index in resultItems.indices where resultItems[index].id != movingItemId {
            let linearIndex = max(0, resultItems[index].page) * itemsPerPage + min(max(0, resultItems[index].slot), itemsPerPage - 1)
            occupiedIndexes[linearIndex] = index
        }

        if occupiedIndexes[targetLinearIndex] != nil {
            var occupiedChain: [(linearIndex: Int, itemIndex: Int)] = []
            var scanLinearIndex = targetLinearIndex

            while let itemIndex = occupiedIndexes[scanLinearIndex] {
                occupiedChain.append((linearIndex: scanLinearIndex, itemIndex: itemIndex))
                scanLinearIndex += 1
            }

            for entry in occupiedChain.reversed() {
                let destinationLinearIndex = entry.linearIndex + 1
                resultItems[entry.itemIndex].page = destinationLinearIndex / itemsPerPage
                resultItems[entry.itemIndex].slot = destinationLinearIndex % itemsPerPage
            }
        }

        guard let movingIndex = resultItems.firstIndex(where: { $0.id == movingItem.id }) else {
            return sourceItems
        }

        resultItems[movingIndex].page = targetLinearIndex / itemsPerPage
        resultItems[movingIndex].slot = targetLinearIndex % itemsPerPage
        return resultItems
    }

    private func layoutSignature(for item: PanelItem) -> String {
        "\(item.id)-\(item.page)-\(item.slot)"
    }

    private func scheduleEdgePageSwitchIfNeeded(at point: CGPoint) {
        guard let session else {
            edgeHint = nil
            cancelPendingPageSwitch()
            return
        }

        let context = PanelLayerDragContext(
            layer: session.state.layer,
            appBundleIdentifier: session.state.appBundleIdentifier
        )
        guard let info = layerFrames[context] else {
            edgeHint = nil
            edgeSwitchLock = nil
            cancelPendingPageSwitch()
            return
        }

        let activeFrame = info.frame.insetBy(dx: -edgeSwitchOuterTolerance, dy: -edgeSwitchVerticalTolerance)
        guard activeFrame.contains(point) else {
            edgeHint = nil
            edgeSwitchLock = nil
            cancelPendingPageSwitch()
            return
        }

        releaseEdgeSwitchLockIfNeeded(at: point, in: info.frame)

        let targetPage: Int?
        let direction: PanelDragEdgeDirection?
        if point.x <= info.frame.minX + edgeSwitchInset, info.currentPage > 0 {
            targetPage = info.currentPage - 1
            direction = .previous
        } else if point.x >= info.frame.maxX - edgeSwitchInset, info.currentPage < info.pageCount - 1 {
            targetPage = info.currentPage + 1
            direction = .next
        } else {
            targetPage = nil
            direction = nil
        }

        if let edgeSwitchLock, edgeSwitchLock == direction {
            edgeHint = nil
            cancelPendingPageSwitch()
            return
        }

        guard let targetPage, let direction else {
            edgeHint = nil
            cancelPendingPageSwitch()
            return
        }

        edgeHint = PanelDragEdgeHint(context: context, direction: direction, targetPage: targetPage)

        let target = PanelDropTarget(
            layer: context.layer,
            appBundleIdentifier: context.appBundleIdentifier,
            page: targetPage,
            slot: 0,
            itemsPerPage: SettingsManager.shared.settings.itemsPerPage(for: context.layer),
            kind: .pageIndicator
        )
        schedulePageSwitch(target)
    }

    private func requestPageSwitch(_ target: PanelDropTarget) {
        edgeHint = nil
        cancelPendingPageSwitch()
        postPageSwitch(target)
    }

    private func schedulePageSwitch(_ target: PanelDropTarget) {
        guard pendingPageSwitchTarget != target else { return }

        cancelPendingPageSwitch()
        pendingPageSwitchTarget = target

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self,
                      self.pendingPageSwitchTarget == target,
                      self.session != nil else {
                    return
                }
                self.postPageSwitch(target)
                self.pendingPageSwitchTarget = nil
                self.pendingPageSwitch = nil
            }
        }
        pendingPageSwitch = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + pageSwitchDelay, execute: workItem)
    }

    private func postPageSwitch(_ target: PanelDropTarget) {
        currentTarget = target
        currentTargetFrame = targetFrames[target]
        edgeHint = nil
        edgeSwitchLock = target.slot == 0 ? edgeDirection(for: target) : nil

        let context = PanelLayerDragContext(
            layer: target.layer,
            appBundleIdentifier: target.appBundleIdentifier
        )
        if var frameInfo = layerFrames[context] {
            frameInfo.currentPage = target.page
            layerFrames[context] = frameInfo
        }

        NotificationCenter.default.post(
            name: .panelDragRequestPageSwitch,
            object: nil,
            userInfo: [
                "layer": target.layer.rawValue,
                "appBundleIdentifier": target.appBundleIdentifier as Any,
                "page": target.page
            ]
        )

        DispatchQueue.main.async { [weak self] in
            guard let self, let session = self.session else { return }
            self.updateDrag(at: session.location)
        }
    }

    private func releaseEdgeSwitchLockIfNeeded(at point: CGPoint, in frame: CGRect) {
        guard let edgeSwitchLock else { return }

        switch edgeSwitchLock {
        case .previous:
            if point.x > frame.minX + edgeSwitchReleaseInset {
                self.edgeSwitchLock = nil
            }
        case .next:
            if point.x < frame.maxX - edgeSwitchReleaseInset {
                self.edgeSwitchLock = nil
            }
        }
    }

    private func edgeDirection(for target: PanelDropTarget) -> PanelDragEdgeDirection? {
        let context = PanelLayerDragContext(
            layer: target.layer,
            appBundleIdentifier: target.appBundleIdentifier
        )
        guard let info = layerFrames[context] else { return nil }

        if target.page > info.currentPage {
            return .next
        }
        if target.page < info.currentPage {
            return .previous
        }
        return nil
    }

    private func cancelPendingPageSwitch() {
        pendingPageSwitch?.cancel()
        pendingPageSwitch = nil
        pendingPageSwitchTarget = nil
    }

    private func reset() {
        session = nil
        currentTarget = nil
        currentTargetFrame = nil
        edgeHint = nil
        previewItemsByContext = [:]
        baseItemsByContext = [:]
        edgeSwitchLock = nil
        cancelPendingPageSwitch()

        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }

        dragWindow = nil
    }
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

struct PanelDropTargetFrameReader: View {
    let target: PanelDropTarget

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    register(proxy)
                }
                .onChange(of: proxy.frame(in: .named("panelDragSpace"))) { _, _ in
                    register(proxy)
                }
                .onChange(of: target) { oldValue, _ in
                    PanelDragManager.shared.unregisterTarget(oldValue)
                    register(proxy)
                }
                .onDisappear {
                    PanelDragManager.shared.unregisterTarget(target)
                }
        }
    }

    private func register(_ proxy: GeometryProxy) {
        PanelDragManager.shared.registerTarget(target, frame: proxy.frame(in: .named("panelDragSpace")))
    }
}

struct PanelLayerFrameReader: View {
    let context: PanelLayerDragContext
    let currentPage: Int
    let pageCount: Int

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    register(proxy)
                }
                .onChange(of: proxy.frame(in: .named("panelDragSpace"))) { _, _ in
                    register(proxy)
                }
                .onChange(of: currentPage) { _, _ in
                    register(proxy)
                }
                .onChange(of: pageCount) { _, _ in
                    register(proxy)
                }
                .onChange(of: context) { oldValue, _ in
                    PanelDragManager.shared.unregisterLayerFrame(context: oldValue)
                    register(proxy)
                }
                .onDisappear {
                    PanelDragManager.shared.unregisterLayerFrame(context: context)
                }
        }
    }

    private func register(_ proxy: GeometryProxy) {
        PanelDragManager.shared.registerLayerFrame(
            context: context,
            frame: proxy.frame(in: .named("panelDragSpace")),
            currentPage: currentPage,
            pageCount: pageCount
        )
    }
}

struct PanelGridMetricsReader: View {
    let context: PanelLayerDragContext
    let columns: Int
    let rows: Int
    let cellSize: CGSize
    let spacing: CGFloat

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    register(proxy)
                }
                .onChange(of: proxy.frame(in: .named("panelDragSpace"))) { _, _ in
                    register(proxy)
                }
                .onChange(of: columns) { _, _ in
                    register(proxy)
                }
                .onChange(of: rows) { _, _ in
                    register(proxy)
                }
                .onChange(of: cellSize.width) { _, _ in
                    register(proxy)
                }
                .onChange(of: cellSize.height) { _, _ in
                    register(proxy)
                }
                .onChange(of: spacing) { _, _ in
                    register(proxy)
                }
                .onChange(of: context) { oldValue, _ in
                    PanelDragManager.shared.unregisterGridMetrics(context: oldValue)
                    register(proxy)
                }
                .onDisappear {
                    PanelDragManager.shared.unregisterGridMetrics(context: context)
                }
        }
    }

    private func register(_ proxy: GeometryProxy) {
        PanelDragManager.shared.registerGridMetrics(
            context: context,
            metrics: PanelGridMetrics(
                frame: proxy.frame(in: .named("panelDragSpace")),
                columns: columns,
                rows: rows,
                cellSize: cellSize,
                spacing: spacing
            )
        )
    }
}

// MARK: - Vibrant Background
/// NSVisualEffectView forced to `.active` so the panel keeps a real frosted-glass
/// look even though it's a `.nonactivatingPanel` that never becomes key window.
/// SwiftUI's `.glassEffect()` degrades to a flat blur in that state, which is why
/// it looked washed-out/gray instead of a proper vibrant material.
struct PanelVibrantBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.state = .active
    }
}

struct PanelView: View {
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var settingsManager = SettingsManager.shared
    @ObservedObject var contextDetector = ContextDetector.shared
    @ObservedObject private var dragManager = PanelDragManager.shared
    @State private var upperPage = 0
    @State private var lowerPagesByApp: [String: Int] = SettingsManager.shared.settings.lowerPageMemory

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

    var upperPageCount: Int {
        max(1, Int(ceil(Double(max(upperItems.count, 1)) / Double(upperItemsPerPage))))
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
        ZStack(alignment: .topLeading) {
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
                    .background(Color.secondary.opacity(0.2))
                    .frame(height: 1.5)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)

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
                    columns: lowerColumns,
                    emptyMessage: lowerLayerEmptyMessage
                )
                .id("\(currentAppBundleId ?? "none")-\(lowerItems.count)")
            }

            if let session = dragManager.session {
                DragGhostItemView(item: session.item)
                    .position(session.location)
                    .allowsHitTesting(false)
                    .zIndex(1000)
            }
        }
        .coordinateSpace(name: "panelDragSpace")
        .background(PanelVibrantBackground(material: settingsManager.settings.panelMaterialStyle.material))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
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

// MARK: - Drag Ghost Item
struct DragGhostItemView: View {
    let item: PanelItem

    var body: some View {
        let settings = SettingsManager.shared.settings
        ItemContentView(item: item, isHovered: true)
            .frame(width: settings.cellWidth, height: settings.cellHeight)
            .scaleEffect(1.08)
            .shadow(color: Color.black.opacity(0.24), radius: 14, x: 0, y: 8)
            .allowsHitTesting(false)
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
    @ObservedObject private var settingsManager = SettingsManager.shared
    @ObservedObject private var dragManager = PanelDragManager.shared
    @State private var showingGroupNameEditor = false
    @State private var editingGroupName = ""
    @State private var pageMovedForward = true
    @State private var isDeletePageHovered = false
    @State private var isAddPageHovered = false
    @State private var showingDeletePageConfirm = false

    private var layerHeight: CGFloat {
        SettingsManager.shared.settings.layerHeight(for: layer)
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
        CGSize(width: settingsManager.settings.cellWidth, height: settingsManager.settings.cellHeight)
    }

    private var gridSpacing: CGFloat {
        settingsManager.settings.itemSpacing
    }

    private var gridContentSize: CGSize {
        CGSize(
            width: CGFloat(gridColumns) * cellSize.width + CGFloat(max(0, gridColumns - 1)) * gridSpacing,
            height: CGFloat(gridRows) * cellSize.height + CGFloat(max(0, gridRows - 1)) * gridSpacing
        )
    }

    private var displayItems: [PanelItem] {
        dragManager.displayedItems(for: layerDragContext, sourceItems: items)
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
        displayItems
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
        VStack(spacing: 4) {
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
                            if currentPageItems.isEmpty {
                                deleteCurrentPage()
                            } else {
                                showingDeletePageConfirm = true
                            }
                        }) {
                            Image(systemName: "minus")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary.opacity(isDeletePageHovered ? 0.8 : 0.5))
                                .frame(width: 14, height: 14)
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
                        goToPage(newPage)
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary.opacity(isAddPageHovered ? 0.8 : 0.5))
                            .frame(width: 14, height: 14)
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
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.04))
                .clipShape(Capsule())
                .frame(width: 112, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
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
                spacing: gridSpacing
            )
            .id(page)
            .frame(width: gridContentSize.width, height: gridContentSize.height)
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
            .transition(.asymmetric(
                insertion: .move(edge: pageMovedForward ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: pageMovedForward ? .leading : .trailing).combined(with: .opacity)
            ))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: page)

            if let emptyMessage, currentPageItems.isEmpty {
                EmptyStateHintView(message: emptyMessage)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 2)
            }

            if pageCount > 1 {
                HStack(spacing: 8) {
                    PageChevronButton(
                        systemName: "chevron.up",
                        isEnabled: page > 0,
                        helpText: "上一页（也可将鼠标悬停在此层区域滚动滚轮）"
                    ) {
                        if page > 0 {
                            goToPage(page - 1)
                        }
                    }

                    HStack(spacing: 6) {
                        ForEach(0..<pageCount, id: \.self) { index in
                            PageIndicatorDot(
                                index: index,
                                currentPage: $page,
                                layer: layer,
                                pageScopeAppBundleId: pageScopeAppBundleId,
                                itemsPerPage: itemsPerPage
                            )
                            .frame(width: 14, height: 14)
                                .onTapGesture {
                                    goToPage(index)
                                }
                        }
                    }

                    PageChevronButton(
                        systemName: "chevron.down",
                        isEnabled: page < pageCount - 1,
                        helpText: "下一页（也可将鼠标悬停在此层区域滚动滚轮）"
                    ) {
                        if page < pageCount - 1 {
                            goToPage(page + 1)
                        }
                    }
                }
                .padding(.bottom, 2)
            }
        }
        .frame(height: layerHeight, alignment: .top)
        .clipped()
        .overlay {
            LayerEdgePageSwitchHint(
                context: layerDragContext,
                currentPage: page,
                pageCount: pageCount
            )
            .allowsHitTesting(false)
        }
        .background(PanelLayerFrameReader(
            context: layerDragContext,
            currentPage: page,
            pageCount: pageCount
        ))
        .onChange(of: page) { _, _ in
            PanelDragManager.shared.unregisterSlotTargets(layer: layer, appBundleIdentifier: pageScopeAppBundleId)
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

            PanelDragManager.shared.unregisterSlotTargets(layer: layer, appBundleIdentifier: pageScopeAppBundleId)
            pageMovedForward = requestedPage >= page
            withAnimation(.easeInOut(duration: 0.18)) {
                page = requestedPage
            }
        }
        .onDisappear {
            PanelDragManager.shared.unregisterSlotTargets(layer: layer, appBundleIdentifier: pageScopeAppBundleId)
            PanelDragManager.shared.unregisterLayerFrame(context: layerDragContext)
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
struct DesktopGridView: NSViewRepresentable {
    let itemsBySlot: [Int: PanelItem]
    let layer: PanelLayer
    let pageScopeAppBundleId: String?
    let currentAppBundleId: String?
    let currentAppName: String?
    let page: Int
    let pageCount: Int
    let columns: Int
    let rows: Int
    let cellSize: CGSize
    let spacing: CGFloat

    private var contentSize: CGSize {
        CGSize(
            width: CGFloat(columns) * cellSize.width + CGFloat(max(0, columns - 1)) * spacing,
            height: CGFloat(rows) * cellSize.height + CGFloat(max(0, rows - 1)) * spacing
        )
    }

    private var itemsPerPage: Int {
        columns * rows
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSCollectionView {
        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: cellSize.width, height: cellSize.height)
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing
        layout.sectionInset = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        let collectionView = PanelGridCollectionView()
        collectionView.collectionViewLayout = layout
        collectionView.backgroundColors = [.clear]
        collectionView.isSelectable = false
        collectionView.allowsMultipleSelection = false
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.gridCoordinator = context.coordinator
        collectionView.register(PanelCollectionItem.self, forItemWithIdentifier: PanelCollectionItem.identifier)

        context.coordinator.collectionView = collectionView
        context.coordinator.configure(
            itemsBySlot: itemsBySlot,
            layer: layer,
            pageScopeAppBundleId: pageScopeAppBundleId,
            currentAppBundleId: currentAppBundleId,
            currentAppName: currentAppName,
            page: page,
            pageCount: pageCount,
            columns: columns,
            rows: rows,
            cellSize: cellSize,
            spacing: spacing
        )
        return collectionView
    }

    func updateNSView(_ collectionView: NSCollectionView, context: Context) {
        if let layout = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout {
            layout.itemSize = NSSize(width: cellSize.width, height: cellSize.height)
            layout.minimumInteritemSpacing = spacing
            layout.minimumLineSpacing = spacing
            layout.invalidateLayout()
        }

        context.coordinator.configure(
            itemsBySlot: itemsBySlot,
            layer: layer,
            pageScopeAppBundleId: pageScopeAppBundleId,
            currentAppBundleId: currentAppBundleId,
            currentAppName: currentAppName,
            page: page,
            pageCount: pageCount,
            columns: columns,
            rows: rows,
            cellSize: cellSize,
            spacing: spacing
        )
        collectionView.reloadData()
    }

    final class Coordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout {
        weak var collectionView: NSCollectionView?

        private var slots: [PanelGridSlot] = []
        private var layer: PanelLayer = .upper
        private var pageScopeAppBundleId: String?
        private var currentAppBundleId: String?
        private var currentAppName: String?
        private var page: Int = 0
        private var pageCount: Int = 1
        private var columns: Int = 0
        private var rows: Int = 0
        private var cellSize: CGSize = .zero
        private var spacing: CGFloat = 0
        private var mouseDownIndex: Int?
        private var mouseDownPoint: CGPoint = .zero
        private var draggingItem: PanelGridSlot?
        private var isDraggingItem = false
        private var didCrossPageDrag = false
        private var lastDragPoint: CGPoint = .zero
        private var pendingPageSwitch: DispatchWorkItem?
        private var pendingPageSwitchTargetPage: Int?
        private var edgeSwitchLock: PanelDragEdgeDirection?
        private var lastVisualMoveTime: TimeInterval = 0

        private let edgeSwitchInset: CGFloat = 46
        private let edgeSwitchReleaseInset: CGFloat = 92
        private let pageSwitchDelay: TimeInterval = 0.42
        private let minimumVisualMoveInterval: TimeInterval = 1.0 / 120.0
        private let minimumDragDistance: CGFloat = 8

        func configure(
            itemsBySlot: [Int: PanelItem],
            layer: PanelLayer,
            pageScopeAppBundleId: String?,
            currentAppBundleId: String?,
            currentAppName: String?,
            page: Int,
            pageCount: Int,
            columns: Int,
            rows: Int,
            cellSize: CGSize,
            spacing: CGFloat
        ) {
            self.layer = layer
            self.pageScopeAppBundleId = pageScopeAppBundleId
            self.currentAppBundleId = currentAppBundleId
            self.currentAppName = currentAppName
            self.page = page
            self.pageCount = max(1, pageCount)
            self.columns = columns
            self.rows = rows
            self.cellSize = cellSize
            self.spacing = spacing

            self.slots = (0..<(columns * rows)).map { slot in
                PanelGridSlot(slot: slot, item: itemsBySlot[slot])
            }
            restoreDraggingItemIfNeeded()
        }

        func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
            slots.count
        }

        func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
            guard let itemView = collectionView.makeItem(
                withIdentifier: PanelCollectionItem.identifier,
                for: indexPath
            ) as? PanelCollectionItem else {
                return NSCollectionViewItem()
            }

            let slot = slots[indexPath.item]
            itemView.configure(
                slot: slot.slot,
                item: slot.item,
                layer: layer,
                currentAppBundleId: currentAppBundleId,
                currentAppName: currentAppName,
                pageScopeAppBundleId: pageScopeAppBundleId,
                page: page,
                cellSize: cellSize
            )
            return itemView
        }

        func mouseDown(at point: CGPoint) {
            cancelPendingPageSwitch()
            mouseDownIndex = indexAt(point)
            mouseDownPoint = point
            isDraggingItem = false
            draggingItem = nil
            didCrossPageDrag = false
            lastDragPoint = point
            edgeSwitchLock = nil
        }

        func mouseDragged(at point: CGPoint) {
            lastDragPoint = point

            guard let sourceIndex = mouseDownIndex,
                  sourceIndex >= 0,
                  sourceIndex < slots.count,
                  slots[sourceIndex].item != nil else {
                return
            }

            // Check minimum drag distance before starting drag
            if !isDraggingItem {
                let deltaX = point.x - mouseDownPoint.x
                let deltaY = point.y - mouseDownPoint.y
                let distance = sqrt(deltaX * deltaX + deltaY * deltaY)

                if distance < minimumDragDistance {
                    return
                }

                isDraggingItem = true
                draggingItem = slots[sourceIndex]
                PanelGridDragVisualState.shared.begin(context: dragContext)
            }

            schedulePageSwitchIfNeeded(at: point)

            guard let targetIndex = indexAt(point),
                  targetIndex != sourceIndex,
                  targetIndex >= 0,
                  targetIndex < slots.count else {
                return
            }

            moveSlot(from: sourceIndex, to: targetIndex)
            mouseDownIndex = targetIndex
        }

        func mouseUp(at point: CGPoint) {
            defer {
                cancelPendingPageSwitch()
                PanelGridDragVisualState.shared.end()
                mouseDownIndex = nil
                draggingItem = nil
                isDraggingItem = false
                didCrossPageDrag = false
                edgeSwitchLock = nil
            }

            if isDraggingItem {
                if didCrossPageDrag {
                    persistCrossPageSlots()
                } else {
                    persistCurrentSlots()
                }
                return
            }

            guard let index = indexAt(point),
                  index >= 0,
                  index < slots.count else {
                return
            }

            let slot = slots[index]
            if let item = slot.item {
                launch(item)
            } else {
                AddItemWindowManager.shared.showAddItemWindow(
                    layer: layer,
                    appBundleId: currentAppBundleId,
                    appName: currentAppName,
                    page: page,
                    slot: slot.slot
                )
            }
        }

        func rightMouseDown(at point: CGPoint, event: NSEvent) {
            guard let collectionView,
                  let index = indexAt(point),
                  index >= 0,
                  index < slots.count,
                  let item = slots[index].item else {
                return
            }

            cancelPendingPageSwitch()

            let menu = NSMenu()
            menu.addItem(
                withTitle: "编辑",
                action: #selector(PanelGridCollectionView.editMenuItem(_:)),
                keyEquivalent: ""
            )
            menu.addItem(
                withTitle: "删除",
                action: #selector(PanelGridCollectionView.deleteMenuItem(_:)),
                keyEquivalent: ""
            )

            menu.items.forEach { menuItem in
                menuItem.target = collectionView
                menuItem.representedObject = item
            }

            NSMenu.popUpContextMenu(menu, with: event, for: collectionView)
        }

        private func indexAt(_ point: CGPoint) -> Int? {
            guard cellSize.width > 0, cellSize.height > 0 else { return nil }

            let stepX = cellSize.width + spacing
            let stepY = cellSize.height + spacing
            let column = Int(point.x / stepX)
            let row = Int(point.y / stepY)

            guard column >= 0, column < columns, row >= 0, row < rows else {
                return nil
            }

            let localX = point.x - CGFloat(column) * stepX
            let localY = point.y - CGFloat(row) * stepY
            guard localX <= cellSize.width, localY <= cellSize.height else {
                return nil
            }

            return row * columns + column
        }

        private func moveSlot(from sourceIndex: Int, to targetIndex: Int) {
            guard sourceIndex != targetIndex,
                  sourceIndex >= 0,
                  sourceIndex < slots.count,
                  targetIndex >= 0,
                  targetIndex < slots.count else {
                return
            }

            let movingSlot = slots.remove(at: sourceIndex)
            slots.insert(movingSlot, at: targetIndex)

            for index in slots.indices {
                slots[index].slot = index
            }

            moveCollectionItem(from: sourceIndex, to: targetIndex)
        }

        private func moveCollectionItem(from sourceIndex: Int, to targetIndex: Int) {
            guard let collectionView else { return }

            let now = CACurrentMediaTime()
            let shouldAnimate = now - lastVisualMoveTime >= minimumVisualMoveInterval
            lastVisualMoveTime = now

            if shouldAnimate {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.09
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    collectionView.animator().moveItem(
                        at: IndexPath(item: sourceIndex, section: 0),
                        to: IndexPath(item: targetIndex, section: 0)
                    )
                }
            } else {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0
                    context.allowsImplicitAnimation = false
                    collectionView.moveItem(
                        at: IndexPath(item: sourceIndex, section: 0),
                        to: IndexPath(item: targetIndex, section: 0)
                    )
                }
            }
        }

        private func restoreDraggingItemIfNeeded() {
            guard isDraggingItem,
                  let draggingItem,
                  let item = draggingItem.item,
                  !slots.isEmpty else {
                return
            }

            if let existingIndex = slots.firstIndex(where: { $0.item?.id == item.id }) {
                slots[existingIndex].item = nil
            }

            let preferredIndex = indexAt(lastDragPoint) ?? clampedIndexAt(lastDragPoint) ?? mouseDownIndex ?? 0
            insertDraggingItem(item, at: preferredIndex)
            mouseDownIndex = min(max(0, preferredIndex), max(0, slots.count - 1))
            collectionView?.reloadData()
        }

        private func insertDraggingItem(_ item: PanelItem, at index: Int) {
            guard !slots.isEmpty else { return }

            let targetIndex = min(max(0, index), slots.count - 1)
            var itemToInsert = item
            itemToInsert.page = page
            itemToInsert.slot = targetIndex

            if slots[targetIndex].item == nil {
                slots[targetIndex].item = itemToInsert
                slots[targetIndex].slot = targetIndex
                return
            }

            var updatedSlots = slots.filter { $0.item?.id != item.id }
            updatedSlots.insert(PanelGridSlot(slot: targetIndex, item: itemToInsert), at: targetIndex)

            if updatedSlots.count > slots.count {
                updatedSlots.removeLast()
            }

            slots = updatedSlots
            renumberSlots()
        }

        private func renumberSlots() {
            for index in slots.indices {
                slots[index].slot = index
                slots[index].item?.page = page
                slots[index].item?.slot = index
            }
        }

        private func schedulePageSwitchIfNeeded(at point: CGPoint) {
            guard isDraggingItem,
                  pageCount > 1,
                  cellSize.width > 0,
                  cellSize.height > 0 else {
                PanelGridDragVisualState.shared.updateEdgeHint(nil)
                cancelPendingPageSwitch()
                return
            }

            let contentWidth = CGFloat(columns) * cellSize.width + CGFloat(max(0, columns - 1)) * spacing
            let contentHeight = CGFloat(rows) * cellSize.height + CGFloat(max(0, rows - 1)) * spacing

            guard point.y >= 0, point.y <= contentHeight else {
                PanelGridDragVisualState.shared.updateEdgeHint(nil)
                cancelPendingPageSwitch()
                return
            }

            releaseEdgeSwitchLockIfNeeded(at: point, contentWidth: contentWidth)

            let direction: PanelDragEdgeDirection?
            let targetPage: Int?
            if point.x <= edgeSwitchInset, page > 0 {
                direction = .previous
                targetPage = page - 1
            } else if point.x >= contentWidth - edgeSwitchInset, page < pageCount - 1 {
                direction = .next
                targetPage = page + 1
            } else {
                direction = nil
                targetPage = nil
            }

            guard let direction, let targetPage else {
                PanelGridDragVisualState.shared.updateEdgeHint(nil)
                cancelPendingPageSwitch()
                return
            }

            guard edgeSwitchLock != direction else {
                PanelGridDragVisualState.shared.updateEdgeHint(nil)
                cancelPendingPageSwitch()
                return
            }

            PanelGridDragVisualState.shared.updateEdgeHint(
                PanelDragEdgeHint(
                    context: dragContext,
                    direction: direction,
                    targetPage: targetPage
                )
            )

            guard pendingPageSwitchTargetPage != targetPage else { return }
            cancelPendingPageSwitch()
            pendingPageSwitchTargetPage = targetPage

            let workItem = DispatchWorkItem { [weak self] in
                DispatchQueue.main.async {
                    self?.requestPageSwitch(to: targetPage, direction: direction)
                }
            }
            pendingPageSwitch = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + pageSwitchDelay, execute: workItem)
        }

        private func requestPageSwitch(to targetPage: Int, direction: PanelDragEdgeDirection) {
            guard isDraggingItem,
                  targetPage >= 0,
                  targetPage < pageCount,
                  targetPage != page,
                  pendingPageSwitchTargetPage == targetPage else {
                return
            }

            cancelPendingPageSwitch()
            didCrossPageDrag = true
            edgeSwitchLock = direction
            PanelGridDragVisualState.shared.updateEdgeHint(nil)

            NotificationCenter.default.post(
                name: .panelDragRequestPageSwitch,
                object: nil,
                userInfo: [
                    "layer": layer.rawValue,
                    "appBundleIdentifier": pageScopeAppBundleId as Any,
                    "page": targetPage
                ]
            )
        }

        private func releaseEdgeSwitchLockIfNeeded(at point: CGPoint, contentWidth: CGFloat) {
            guard let edgeSwitchLock else { return }

            switch edgeSwitchLock {
            case .previous:
                if point.x > edgeSwitchReleaseInset {
                    self.edgeSwitchLock = nil
                }
            case .next:
                if point.x < contentWidth - edgeSwitchReleaseInset {
                    self.edgeSwitchLock = nil
                }
            }
        }

        private func cancelPendingPageSwitch() {
            pendingPageSwitch?.cancel()
            pendingPageSwitch = nil
            pendingPageSwitchTargetPage = nil
        }

        private var dragContext: PanelLayerDragContext {
            PanelLayerDragContext(layer: layer, appBundleIdentifier: pageScopeAppBundleId)
        }

        private func persistCurrentSlots() {
            let itemsPerPage = max(1, columns * rows)
            var pageItems: [PanelItem] = []

            for index in slots.indices {
                guard var item = slots[index].item else { continue }
                item.page = page + index / itemsPerPage
                item.slot = index % itemsPerPage
                pageItems.append(item)
                slots[index].item = item
                slots[index].slot = index % itemsPerPage
            }

            DataManager.shared.replacePageItems(
                for: layer,
                appBundleIdentifier: pageScopeAppBundleId,
                page: page,
                with: pageItems
            )
        }

        private func persistCrossPageSlots() {
            guard let movingItemId = draggingItem?.item?.id,
                  let targetIndex = slots.firstIndex(where: { $0.item?.id == movingItemId }) else {
                persistCurrentSlots()
                return
            }

            DataManager.shared.moveItem(
                id: movingItemId,
                layer: layer,
                appBundleIdentifier: pageScopeAppBundleId,
                toPage: page,
                slotIndex: targetIndex,
                itemsPerPage: max(1, columns * rows)
            )
        }

        private func clampedIndexAt(_ point: CGPoint) -> Int? {
            guard columns > 0,
                  rows > 0,
                  !slots.isEmpty,
                  cellSize.width > 0,
                  cellSize.height > 0 else {
                return nil
            }

            let stepX = cellSize.width + spacing
            let stepY = cellSize.height + spacing
            let column = min(max(0, Int(point.x / stepX)), columns - 1)
            let row = min(max(0, Int(point.y / stepY)), rows - 1)
            let index = row * columns + column
            return min(max(0, index), slots.count - 1)
        }

        private func launch(_ item: PanelItem) {
            switch item.type {
            case .application:
                AppLauncher.shared.launchApp(at: item.path)
            case .website:
                AppLauncher.shared.openWebsite(url: item.path, browserPath: item.browserPath)
            }

            NotificationCenter.default.post(name: .hidePanel, object: nil)
        }
    }
}

struct PanelGridSlot {
    var slot: Int
    var item: PanelItem?
}

final class PanelGridCollectionView: NSCollectionView {
    weak var gridCoordinator: DesktopGridView.Coordinator?

    override func mouseDown(with event: NSEvent) {
        gridCoordinator?.mouseDown(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseDragged(with event: NSEvent) {
        gridCoordinator?.mouseDragged(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        gridCoordinator?.mouseUp(at: convert(event.locationInWindow, from: nil))
    }

    override func rightMouseDown(with event: NSEvent) {
        gridCoordinator?.rightMouseDown(at: convert(event.locationInWindow, from: nil), event: event)
    }

    @objc func editMenuItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? PanelItem else { return }
        AddItemWindowManager.shared.showEditItemWindow(item: item)
    }

    @objc func deleteMenuItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? PanelItem else { return }
        DataManager.shared.deleteItem(item)
    }
}

final class PanelCollectionItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("PanelCollectionItem")

    private var hostingController: NSHostingController<PanelCollectionCellView>?

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    func configure(
        slot: Int,
        item: PanelItem?,
        layer: PanelLayer,
        currentAppBundleId: String?,
        currentAppName: String?,
        pageScopeAppBundleId: String?,
        page: Int,
        cellSize: CGSize
    ) {
        let cellView = PanelCollectionCellView(item: item, cellSize: cellSize)

        if let hostingController {
            hostingController.rootView = cellView
        } else {
            let hostingController = NSHostingController(rootView: cellView)
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            addChild(hostingController)
            view.addSubview(hostingController.view)
            NSLayoutConstraint.activate([
                hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            self.hostingController = hostingController
        }
    }
}

struct PanelCollectionCellView: View {
    let item: PanelItem?
    let cellSize: CGSize
    @ObservedObject private var gridDragVisualState = PanelGridDragVisualState.shared
    @State private var isHovered = false

    private var shouldShowHover: Bool {
        isHovered && gridDragVisualState.activeContext == nil
    }

    var body: some View {
        Group {
            if let item {
                ItemContentView(item: item, isHovered: isHovered)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(shouldShowHover ? Color.primary.opacity(0.05) : Color.clear)

                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            shouldShowHover ? Color.secondary.opacity(0.4) : Color.secondary.opacity(0.25),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                        )

                    VStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: shouldShowHover ? 20 : 16, weight: .medium))
                            .foregroundColor(.secondary.opacity(shouldShowHover ? 0.6 : 0.5))

                        if shouldShowHover {
                            Text("添加")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }
                }
            }
        }
        .frame(width: cellSize.width, height: cellSize.height)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Edge Page Switch Hint
struct LayerEdgePageSwitchHint: View {
    let context: PanelLayerDragContext
    let currentPage: Int
    let pageCount: Int
    @ObservedObject private var dragManager = PanelDragManager.shared
    @ObservedObject private var gridDragVisualState = PanelGridDragVisualState.shared

    private var hint: PanelDragEdgeHint? {
        if let edgeHint = gridDragVisualState.edgeHint,
           edgeHint.context == context {
            return edgeHint
        }

        guard let edgeHint = dragManager.edgeHint,
              edgeHint.context == context else {
            return nil
        }
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
            (dragManager.isDragging(in: context) || gridDragVisualState.isDragging(in: context))
    }

    var body: some View {
        HStack {
            EdgePageSwitchBar(
                direction: .previous,
                isActive: hint?.direction == .previous,
                isVisible: shouldShowPassiveHints && canSwitchPrevious
            )

            Spacer()

            EdgePageSwitchBar(
                direction: .next,
                isActive: hint?.direction == .next,
                isVisible: shouldShowPassiveHints && canSwitchNext
            )
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 28)
        .animation(.spring(response: 0.22, dampingFraction: 0.75), value: hint)
        .animation(.easeInOut(duration: 0.16), value: shouldShowPassiveHints)
    }
}

struct EdgePageSwitchBar: View {
    let direction: PanelDragEdgeDirection
    let isActive: Bool
    let isVisible: Bool

    private var iconName: String {
        direction == .previous ? "chevron.left" : "chevron.right"
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(isActive ? 0.98 : 0.72))

            RoundedRectangle(cornerRadius: 999)
                .fill(Color.white.opacity(isActive ? 0.86 : 0.42))
                .frame(width: 3, height: isActive ? 72 : 46)
        }
        .frame(width: isActive ? 24 : 18)
        .frame(maxHeight: .infinity)
        .background(
            Capsule()
                .fill(Color.accentColor.opacity(isActive ? 0.72 : 0.26))
                .shadow(color: Color.accentColor.opacity(isActive ? 0.32 : 0.12), radius: isActive ? 12 : 5, x: 0, y: 0)
        )
        .scaleEffect(isActive ? 1.05 : 1.0)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.18), value: isActive)
        .animation(.easeInOut(duration: 0.15), value: isVisible)
    }
}

// MARK: - Empty Slot
struct EmptySlotView: View {
    let layer: PanelLayer
    let currentAppBundleId: String?
    let currentAppName: String?
    let pageScopeAppBundleId: String?
    let page: Int
    let slotIndex: Int
    let itemsPerPage: Int
    let cellSize: CGSize
    @ObservedObject private var dragManager = PanelDragManager.shared
    @State private var isHovered = false

    private var dropTarget: PanelDropTarget {
        PanelDropTarget(
            layer: layer,
            appBundleIdentifier: pageScopeAppBundleId,
            page: page,
            slot: slotIndex,
            itemsPerPage: itemsPerPage,
            kind: .slot
        )
    }

    private var isDropTarget: Bool {
        dragManager.isHovered(dropTarget)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill((isHovered || isDropTarget) ? Color.primary.opacity(0.05) : Color.clear)

            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isDropTarget ? Color.accentColor.opacity(0.7) : (isHovered ? Color.secondary.opacity(0.4) : Color.secondary.opacity(0.15)),
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
        .frame(width: cellSize.width, height: cellSize.height)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            AddItemWindowManager.shared.showAddItemWindow(
                layer: layer,
                appBundleId: currentAppBundleId,
                appName: currentAppName,
                page: page,
                slot: slotIndex
            )
        }
    }
}

// MARK: - Drag Handle
struct DragHandleView: View {
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 4) {
            Spacer()
            // Three dots indicator
            HStack(spacing: 4) {
                ForEach(0..<3) { _ in
                    Circle()
                        .fill(Color.secondary.opacity(isHovered ? 0.7 : 0.6))
                        .frame(width: 5, height: 5)
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
    @State private var isHovered = false

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
        .background(Color.primary.opacity(isHovered ? 0.08 : 0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
        .cornerRadius(8)
        .frame(maxWidth: 180)
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
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.035))
        .cornerRadius(10)
    }
}

// MARK: - Item Content
struct ItemContentView: View {
    let item: PanelItem
    let isHovered: Bool

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
                .help(item.name)
        }
    }
}

// MARK: - Page Chevron Button
struct PageChevronButton: View {
    let systemName: String
    let isEnabled: Bool
    let helpText: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(.secondary.opacity(isEnabled ? (isHovered ? 0.85 : 0.55) : 0.15))
            .frame(width: 16, height: 16)
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
    let layer: PanelLayer
    let pageScopeAppBundleId: String?
    let itemsPerPage: Int
    @ObservedObject private var dragManager = PanelDragManager.shared
    @State private var isHovered = false

    private var dropTarget: PanelDropTarget {
        PanelDropTarget(
            layer: layer,
            appBundleIdentifier: pageScopeAppBundleId,
            page: index,
            slot: 0,
            itemsPerPage: itemsPerPage,
            kind: .pageIndicator
        )
    }

    private var isDropTarget: Bool {
        dragManager.isHovered(dropTarget)
    }

    private var isCurrent: Bool {
        currentPage == index
    }

    var body: some View {
        Circle()
            .fill(isCurrent ? Color.accentColor : Color.secondary.opacity(isHovered ? 0.75 : 0.5))
            .frame(
                width: isDropTarget ? 10 : (isCurrent ? 9 : (isHovered ? 8 : 7)),
                height: isDropTarget ? 10 : (isCurrent ? 9 : (isHovered ? 8 : 7))
            )
            .overlay(
                Circle()
                    .stroke(isDropTarget ? Color.accentColor.opacity(0.55) : Color.clear, lineWidth: 3)
                    .frame(width: 14, height: 14)
            )
            .contentShape(Circle())
            .background(PanelDropTargetFrameReader(target: dropTarget))
            .animation(.easeInOut(duration: 0.15), value: isDropTarget)
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

// MARK: - Item Button
struct ItemButton: View {
    let item: PanelItem
    let layer: PanelLayer
    let pageScopeAppBundleId: String?
    let targetPage: Int
    let slotIndex: Int
    let itemsPerPage: Int
    let cellSize: CGSize
    @ObservedObject private var dragManager = PanelDragManager.shared
    @State private var isHovered = false
    @State private var showingEditSheet = false
    @State private var scale: CGFloat = 1.0

    private var dropTarget: PanelDropTarget {
        PanelDropTarget(
            layer: layer,
            appBundleIdentifier: pageScopeAppBundleId,
            page: targetPage,
            slot: slotIndex,
            itemsPerPage: itemsPerPage,
            kind: .slot
        )
    }

    private var isDropTarget: Bool {
        dragManager.isHovered(dropTarget)
    }

    private var isDraggedItem: Bool {
        dragManager.session?.state.itemId == item.id
    }

    var body: some View {
        ItemContentView(item: item, isHovered: isHovered)
        .frame(width: cellSize.width, height: cellSize.height)
        .scaleEffect(scale)
        .opacity(isDraggedItem ? 0.55 : 1.0)
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
        .simultaneousGesture(dragGesture)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: scale)
        .animation(.easeInOut(duration: 0.2), value: isDropTarget)
        .contextMenu {
            Button("编辑") {
                AddItemWindowManager.shared.showEditItemWindow(item: item)
            }

            switch item.type {
            case .application:
                Button("在 Finder 中显示") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
                }
            case .website:
                Button("复制链接") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(item.path, forType: .string)
                }
            }

            Divider()

            Button("删除", role: .destructive) {
                DataManager.shared.deleteItem(item)
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named("panelDragSpace"))
            .onChanged { value in
                if dragManager.session?.state.itemId != item.id {
                    withAnimation(.easeOut(duration: 0.12)) {
                        scale = 0.95
                    }
                    dragManager.beginDrag(item: item, appBundleIdentifier: pageScopeAppBundleId, at: value.location)
                }
                dragManager.updateDrag(at: value.location)
            }
            .onEnded { value in
                dragManager.updateDrag(at: value.location)
                dragManager.endDrag()
                resetLocalDragState()
            }
    }

    private func resetLocalDragState() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
            scale = 1.0
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
    static let panelDragRequestPageSwitch = Notification.Name("panelDragRequestPageSwitch")
}
