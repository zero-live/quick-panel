//
//  PanelLayoutEngine.swift
//  Quick Panel
//
//  Created by Codex on 2026/08/18.
//

import Foundation

struct GridPosition: Hashable, Codable {
    var page: Int
    var slot: Int
}

/// Keeps positions stable while making every item addressable by the current grid size.
/// This is deliberately free of persistence and UI concerns so its invariants can be tested.
enum PanelLayoutEngine {
    static func normalized(
        _ sourceItems: [PanelItem],
        itemsPerPage: (PanelLayer) -> Int
    ) -> [PanelItem] {
        var items = sourceItems
        let groupedIndices = Dictionary(grouping: items.indices, by: { scopeKey(for: items[$0]) })

        for indices in groupedIndices.values {
            let sortedIndices = indices.sorted { lhs, rhs in
                sortByPosition(items[lhs], items[rhs])
            }
            guard let firstIndex = sortedIndices.first else { continue }

            let capacity = max(1, itemsPerPage(items[firstIndex].layer))
            var usedPositions = Set<GridPosition>()

            for index in sortedIndices {
                var position = GridPosition(
                    page: max(0, items[index].page),
                    slot: min(max(0, items[index].slot), capacity - 1)
                )

                while usedPositions.contains(position) {
                    let nextLinearIndex = position.page * capacity + position.slot + 1
                    position = GridPosition(
                        page: nextLinearIndex / capacity,
                        slot: nextLinearIndex % capacity
                    )
                }

                usedPositions.insert(position)
                items[index].page = position.page
                items[index].slot = position.slot
            }
        }

        return items
    }

    private static func scopeKey(for item: PanelItem) -> String {
        switch item.layer {
        case .upper:
            return item.layer.rawValue
        case .lower:
            return "\(item.layer.rawValue)::\(item.appBundleIdentifier ?? "__unbound__")"
        }
    }

    private static func sortByPosition(_ lhs: PanelItem, _ rhs: PanelItem) -> Bool {
        if lhs.page != rhs.page {
            return lhs.page < rhs.page
        }

        if lhs.slot != rhs.slot {
            return lhs.slot < rhs.slot
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }
}
