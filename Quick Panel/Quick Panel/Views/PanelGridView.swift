//
//  PanelGridView.swift
//  Quick Panel
//
//  Extracted from PanelView.swift.
//

import Combine
import SwiftUI
import AppKit

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
    let visualScale: CGFloat

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
            spacing: spacing,
            visualScale: visualScale
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
            spacing: spacing,
            visualScale: visualScale
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
        private var visualScale: CGFloat = 1
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

        private var edgeSwitchInset: CGFloat { 46 * visualScale }
        private var edgeSwitchReleaseInset: CGFloat { 92 * visualScale }
        private let pageSwitchDelay: TimeInterval = 0.42
        private let minimumVisualMoveInterval: TimeInterval = 1.0 / 120.0
        private var minimumDragDistance: CGFloat { 8 * visualScale }

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
            spacing: CGFloat,
            visualScale: CGFloat
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
            self.visualScale = visualScale

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
                cellSize: cellSize,
                visualScale: visualScale
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
        cellSize: CGSize,
        visualScale: CGFloat
    ) {
        let cellView = PanelCollectionCellView(item: item, cellSize: cellSize, visualScale: visualScale)

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
    let visualScale: CGFloat
    @ObservedObject private var gridDragVisualState = PanelGridDragVisualState.shared
    @State private var isHovered = false

    private var shouldShowHover: Bool {
        isHovered && gridDragVisualState.activeContext == nil
    }

    var body: some View {
        Group {
            if let item {
                ItemContentView(item: item, isHovered: isHovered, scale: visualScale)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10 * visualScale)
                        .fill(shouldShowHover ? Color.primary.opacity(0.05) : Color.clear)

                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            shouldShowHover ? Color.secondary.opacity(0.4) : Color.secondary.opacity(0.25),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                        )

                    VStack(spacing: 6 * visualScale) {
                        Image(systemName: "plus")
                            .font(.system(size: (shouldShowHover ? 20 : 16) * visualScale, weight: .medium))
                            .foregroundColor(.secondary.opacity(shouldShowHover ? 0.6 : 0.5))

                        if shouldShowHover {
                            Text("添加")
                                .font(.system(size: 10 * visualScale))
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
