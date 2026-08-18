//
//  PanelDocument.swift
//  Quick Panel
//
//  Created by Codex on 2026/08/18.
//

import Foundation

/// The complete persisted state of a panel. Keeping related state together
/// prevents page metadata and item positions from being saved independently.
struct PanelDocument: Codable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var items: [PanelItem]
    var pageGroups: PageGroup
    var pageCounts: [String: Int]

    init(
        schemaVersion: Int = PanelDocument.currentSchemaVersion,
        items: [PanelItem] = [],
        pageGroups: PageGroup = PageGroup(),
        pageCounts: [String: Int] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.items = items
        self.pageGroups = pageGroups
        self.pageCounts = pageCounts
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, items, pageGroups, pageCounts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        items = try container.decodeIfPresent([PanelItem].self, forKey: .items) ?? []
        pageGroups = try container.decodeIfPresent(PageGroup.self, forKey: .pageGroups) ?? PageGroup()
        pageCounts = try container.decodeIfPresent([String: Int].self, forKey: .pageCounts) ?? [:]
    }
}
