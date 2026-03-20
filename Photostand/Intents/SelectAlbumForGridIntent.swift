//
//  SelectAlbumForGridIntent.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/20.
//

import AppIntents

struct SelectAlbumForGridIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("PhotoGrid.Intent.Title", table: "Widgets")
    static var description = IntentDescription(
        LocalizedStringResource("PhotoGrid.Intent.Description", table: "Widgets")
    )

    @Parameter(title: LocalizedStringResource("PhotoGrid.Intent.Album", table: "Widgets"))
    var album: AlbumEntity?
}
