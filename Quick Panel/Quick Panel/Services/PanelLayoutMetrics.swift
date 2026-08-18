//
//  PanelLayoutMetrics.swift
//  Quick Panel
//
//  Resolves the panel's runtime size for the screen where it is shown.
//

import AppKit
import Combine
import Foundation

struct PanelLayoutMetrics: Equatable {
    let scale: CGFloat
    let panelSize: CGSize
    let cellSize: CGSize
    let itemSpacing: CGFloat
    let horizontalPadding: CGFloat
    let headerHeight: CGFloat
    let baseVerticalPadding: CGFloat
    let gridBottomPadding: CGFloat
    let pageIndicatorHeight: CGFloat
    let dragHandleHeight: CGFloat
    let interLayerHeight: CGFloat
    let dividerVerticalPadding: CGFloat
    let dividerThickness: CGFloat

    var isCompact: Bool {
        scale < 0.85
    }

    var iconSize: CGFloat {
        48 * scale
    }

    var itemLabelFontSize: CGFloat {
        11 * scale
    }

    func layerHeight(for layer: PanelLayer, settings: AppSettings) -> CGFloat {
        let rows = settings.gridRows(for: layer)
        let gridHeight = CGFloat(rows) * cellSize.height + CGFloat(max(0, rows - 1)) * itemSpacing
        return headerHeight
            + baseVerticalPadding
            + gridHeight
            + gridBottomPadding
            + pageIndicatorHeight
    }

    static func resolve(settings: AppSettings, screen: NSScreen?) -> PanelLayoutMetrics {
        resolve(
            settings: settings,
            maximumPanelSize: availablePanelSize(for: screen)
        )
    }

    static func resolve(settings: AppSettings, maximumPanelSize: CGSize) -> PanelLayoutMetrics {
        let maxColumns = max(settings.upperGridColumns, settings.lowerGridColumns)
        let baseWidth = CGFloat(maxColumns) * settings.cellWidth
            + CGFloat(max(0, maxColumns - 1)) * settings.itemSpacing
            + 40
        let baseUpperHeight = baseLayerHeight(for: .upper, settings: settings)
        let baseLowerHeight = baseLayerHeight(for: .lower, settings: settings)
        let baseHeight = baseUpperHeight + baseLowerHeight + 44

        let scale: CGFloat
        if settings.panelSizingMode == .fixed {
            scale = 1
        } else {
            scale = min(
                1,
                maximumPanelSize.width / max(1, baseWidth),
                maximumPanelSize.height / max(1, baseHeight)
            )
        }

        return PanelLayoutMetrics(
            scale: scale,
            panelSize: CGSize(width: baseWidth * scale, height: baseHeight * scale),
            cellSize: CGSize(width: settings.cellWidth * scale, height: settings.cellHeight * scale),
            itemSpacing: settings.itemSpacing * scale,
            horizontalPadding: 20 * scale,
            headerHeight: AppSettings.layerHeaderHeight * scale,
            baseVerticalPadding: AppSettings.layerBaseVerticalPadding * scale,
            gridBottomPadding: AppSettings.layerGridBottomPadding * scale,
            pageIndicatorHeight: AppSettings.layerPageIndicatorHeight * scale,
            dragHandleHeight: 24 * scale,
            interLayerHeight: 20 * scale,
            dividerVerticalPadding: 6 * scale,
            dividerThickness: max(1, 1.5 * scale)
        )
    }

    private static func baseLayerHeight(for layer: PanelLayer, settings: AppSettings) -> CGFloat {
        let rows = settings.gridRows(for: layer)
        let gridHeight = CGFloat(rows) * settings.cellHeight + CGFloat(max(0, rows - 1)) * settings.itemSpacing
        return AppSettings.layerHeaderHeight
            + AppSettings.layerBaseVerticalPadding
            + gridHeight
            + AppSettings.layerGridBottomPadding
            + AppSettings.layerPageIndicatorHeight
    }

    private static func availablePanelSize(for screen: NSScreen?) -> CGSize {
        guard let visibleFrame = screen?.visibleFrame, !visibleFrame.isEmpty else {
            return CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }

        return CGSize(
            width: max(1, visibleFrame.width * 0.90),
            height: max(1, visibleFrame.height * 0.88)
        )
    }
}

@MainActor
final class PanelLayoutManager: ObservableObject {
    static let shared = PanelLayoutManager()

    @Published private(set) var metrics: PanelLayoutMetrics

    private init() {
        metrics = PanelLayoutMetrics.resolve(
            settings: SettingsManager.shared.settings,
            screen: NSScreen.main
        )
    }

    func update(for screen: NSScreen?) {
        let resolvedMetrics = PanelLayoutMetrics.resolve(
            settings: SettingsManager.shared.settings,
            screen: screen
        )

        guard resolvedMetrics != metrics else { return }
        metrics = resolvedMetrics
    }
}
