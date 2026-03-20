//
//  AlbumView+Preferences.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/20.
//

extension AlbumView {

    var preferencesAlbumID: String {
        currentAlbum?.id ?? "__root__"
    }

    func loadPreferences() async {
        let prefs = await DataActor.shared.preferences(forAlbumWithID: preferencesAlbumID)
        albumSort = SortType(rawValue: prefs.albumSort) ?? .nameAscending
        albumStyle = ViewStyle(rawValue: prefs.albumViewStyle) ?? .grid
        albumColumnCount = prefs.albumColumnCount
        picSortType = PicSortType(rawValue: prefs.picSort) ?? .dateAddedDescending
        columnCount = prefs.picColumnCount
        albumSortState = albumSort
        albumStyleState = albumStyle
    }

    func savePreference() {
        let prefs = AlbumPreferences(
            albumID: preferencesAlbumID,
            albumSort: albumSort.rawValue,
            albumViewStyle: albumStyle.rawValue,
            albumColumnCount: albumColumnCount,
            picSort: picSortType.rawValue,
            picColumnCount: columnCount
        )
        Task {
            await DataActor.shared.savePreferences(prefs)
        }
    }
}
