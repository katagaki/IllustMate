//
//  SelectAlbumIntent.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/20.
//

import AppIntents

struct SelectAlbumIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("Photostand.Intent.Title", table: "Widgets")
    static var description = IntentDescription(
        LocalizedStringResource("Photostand.Intent.Description", table: "Widgets")
    )

    @Parameter(title: LocalizedStringResource("Photostand.Intent.Album", table: "Widgets"))
    var album: AlbumEntity?

    @Parameter(
        title: LocalizedStringResource("Photostand.Intent.RefreshInterval", table: "Widgets"),
        default: .threeHours
    )
    var refreshInterval: RefreshInterval
}
