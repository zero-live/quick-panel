//
//  PanelLayoutEngineTests.swift
//  Quick PanelTests
//

import XCTest
@testable import Quick_Panel

@MainActor
final class PanelLayoutEngineTests: XCTestCase {
    func testShrinkingGridMovesOverflowItemsToTheNextPage() {
        let items = (0..<12).map { slot in
            makeItem(name: "Item \(slot)", page: 0, slot: slot)
        }

        let normalized = PanelLayoutEngine.normalized(items) { _ in 9 }

        XCTAssertEqual(normalized.count, 12)
        XCTAssertEqual(normalized.prefix(9).map(\.page), Array(repeating: 0, count: 9))
        XCTAssertEqual(normalized.prefix(9).map(\.slot), Array(0..<9))
        XCTAssertEqual(normalized.suffix(3).map(\.page), Array(repeating: 1, count: 3))
        XCTAssertEqual(normalized.suffix(3).map(\.slot), [0, 1, 2])
    }

    func testNormalizationMakesPositionsUniqueWithinAScope() {
        let first = makeItem(name: "First", page: 0, slot: 0)
        let second = makeItem(name: "Second", page: 0, slot: 0)
        let third = makeItem(name: "Third", page: -1, slot: -3)

        let normalized = PanelLayoutEngine.normalized([first, second, third]) { _ in 9 }
        let positions = Set(normalized.map { GridPosition(page: $0.page, slot: $0.slot) })

        XCTAssertEqual(positions.count, normalized.count)
        XCTAssertTrue(normalized.allSatisfy { $0.page >= 0 && (0..<9).contains($0.slot) })
    }

    func testLowerLayerScopesAreNormalizedIndependently() {
        let appA = makeItem(name: "A", layer: .lower, appBundleIdentifier: "com.example.a", page: 0, slot: 0)
        let appB = makeItem(name: "B", layer: .lower, appBundleIdentifier: "com.example.b", page: 0, slot: 0)
        let appASecond = makeItem(name: "A Second", layer: .lower, appBundleIdentifier: "com.example.a", page: 0, slot: 0)

        let normalized = PanelLayoutEngine.normalized([appA, appB, appASecond]) { _ in 9 }
        let appAPositions = normalized
            .filter { $0.appBundleIdentifier == "com.example.a" }
            .map { GridPosition(page: $0.page, slot: $0.slot) }
        let appBPosition = normalized.first { $0.appBundleIdentifier == "com.example.b" }

        XCTAssertEqual(Set(appAPositions).count, 2)
        XCTAssertEqual(appBPosition?.page, 0)
        XCTAssertEqual(appBPosition?.slot, 0)
    }

    func testPanelDocumentRoundTripsAllRelatedStateTogether() throws {
        let item = makeItem(name: "Saved", page: 2, slot: 3)
        var groups = PageGroup()
        groups.setGroupName(scopeKey: "upper", page: 2, name: "工作")
        let document = PanelDocument(
            items: [item],
            pageGroups: groups,
            pageCounts: ["upper": 4]
        )

        let decoded = try JSONDecoder().decode(
            PanelDocument.self,
            from: JSONEncoder().encode(document)
        )

        XCTAssertEqual(decoded.schemaVersion, PanelDocument.currentSchemaVersion)
        XCTAssertEqual(decoded.items.count, 1)
        XCTAssertEqual(decoded.items.first?.id, item.id)
        XCTAssertEqual(decoded.pageGroups.getGroupName(scopeKey: "upper", page: 2), "工作")
        XCTAssertEqual(decoded.pageCounts["upper"], 4)
    }

    func testPanelDocumentUsesSafeDefaultsForMissingFields() throws {
        let data = Data("{\"items\":[]}".utf8)

        let document = try JSONDecoder().decode(PanelDocument.self, from: data)

        XCTAssertEqual(document.schemaVersion, 1)
        XCTAssertTrue(document.items.isEmpty)
        XCTAssertTrue(document.pageGroups.groups.isEmpty)
        XCTAssertTrue(document.pageCounts.isEmpty)
    }

    func testAdaptiveMetricsKeepBaseSizeWhenTheScreenHasEnoughRoom() {
        let metrics = PanelLayoutMetrics.resolve(
            settings: .default,
            maximumPanelSize: CGSize(width: 1_000, height: 1_000)
        )

        XCTAssertEqual(metrics.scale, 1)
        XCTAssertEqual(metrics.panelSize.width, 368)
        XCTAssertEqual(metrics.panelSize.height, 776)
        XCTAssertEqual(metrics.cellSize, CGSize(width: 70, height: 90))
    }

    func testAdaptiveMetricsShrinkEveryVisualMetricToFitTheAvailableScreen() {
        var settings = AppSettings.default
        settings.upperGridColumns = 5
        settings.upperGridRows = 5
        settings.lowerGridColumns = 5
        settings.lowerGridRows = 5
        settings.itemSpacing = 24
        settings.cellWidth = 100
        settings.cellHeight = 120

        let availableSize = CGSize(width: 900, height: 800)
        let metrics = PanelLayoutMetrics.resolve(
            settings: settings,
            maximumPanelSize: availableSize
        )

        XCTAssertLessThan(metrics.scale, 1)
        XCTAssertTrue(metrics.isCompact)
        XCTAssertLessThanOrEqual(metrics.panelSize.width, availableSize.width)
        XCTAssertLessThanOrEqual(metrics.panelSize.height, availableSize.height)
        XCTAssertEqual(metrics.cellSize.width, settings.cellWidth * metrics.scale, accuracy: 0.001)
        XCTAssertEqual(metrics.itemSpacing, settings.itemSpacing * metrics.scale, accuracy: 0.001)
    }

    func testFixedSizingModeKeepsTheConfiguredSize() {
        var settings = AppSettings.default
        settings.panelSizingMode = .fixed

        let metrics = PanelLayoutMetrics.resolve(
            settings: settings,
            maximumPanelSize: CGSize(width: 200, height: 200)
        )

        XCTAssertEqual(metrics.scale, 1)
        XCTAssertEqual(metrics.panelSize, CGSize(width: 368, height: 776))
    }

    private func makeItem(
        name: String,
        layer: PanelLayer = .upper,
        appBundleIdentifier: String? = nil,
        page: Int,
        slot: Int
    ) -> PanelItem {
        PanelItem(
            name: name,
            type: .application,
            path: "/Applications/Example.app",
            layer: layer,
            appBundleIdentifier: appBundleIdentifier,
            page: page,
            slot: slot
        )
    }
}
