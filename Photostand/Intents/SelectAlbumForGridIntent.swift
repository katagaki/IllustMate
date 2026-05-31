import AppIntents

struct SelectAlbumForGridIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("PhotoGrid.Intent.Title", table: "Widgets")
    static var description = IntentDescription(
        LocalizedStringResource("PhotoGrid.Intent.Description", table: "Widgets")
    )

    @Parameter(title: LocalizedStringResource("PhotoGrid.Intent.Library", table: "Widgets"))
    var library: LibraryEntity?

    @Parameter(title: LocalizedStringResource("PhotoGrid.Intent.Album", table: "Widgets"))
    var album: GridAlbumEntity?
}
