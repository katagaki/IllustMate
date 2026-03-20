//
//  RefreshInterval.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/20.
//

import AppIntents

enum RefreshInterval: String, CaseIterable, AppEnum {
    case threeHours = "3h"
    case sixHours = "6h"
    case twelveHours = "12h"
    case twentyFourHours = "24h"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource(
            "Photostand.Entity.RefreshInterval",
            table: "Widgets"
        )
    )
    static var caseDisplayRepresentations: [RefreshInterval: DisplayRepresentation] = [
        .threeHours: DisplayRepresentation(
            title: LocalizedStringResource("Photostand.RefreshInterval.3Hours", table: "Widgets")
        ),
        .sixHours: DisplayRepresentation(
            title: LocalizedStringResource("Photostand.RefreshInterval.6Hours", table: "Widgets")
        ),
        .twelveHours: DisplayRepresentation(
            title: LocalizedStringResource("Photostand.RefreshInterval.12Hours", table: "Widgets")
        ),
        .twentyFourHours: DisplayRepresentation(
            title: LocalizedStringResource("Photostand.RefreshInterval.24Hours", table: "Widgets")
        )
    ]

    var seconds: TimeInterval {
        switch self {
        case .threeHours: return 10800
        case .sixHours: return 21600
        case .twelveHours: return 43200
        case .twentyFourHours: return 86400
        }
    }

    var entryCount: Int {
        Int(86400 / seconds)
    }
}
