//
//  NavigationManager.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Foundation

@MainActor
class NavigationManager: ObservableObject {

    @Published var collectionTabPath: [ViewPath] = []
    @Published var albumsTabPath: [ViewPath] = []
    @Published var picsTabPath: [ViewPath] = []
    @Published var moreTabPath: [ViewPath] = []

    func popAll() {
        collectionTabPath.removeAll()
        albumsTabPath.removeAll()
        picsTabPath.removeAll()
        moreTabPath.removeAll()
    }

    func popToRoot(for tab: TabType) {
        switch tab {
        case .collection:
            collectionTabPath.removeAll()
        case .albums:
            albumsTabPath.removeAll()
        case .pics:
            picsTabPath.removeAll()
        case .more:
            moreTabPath.removeAll()
        }
    }

    func push(_ viewPath: ViewPath, for tab: TabType) {
        switch tab {
        case .collection:
            collectionTabPath.append(viewPath)
        case .albums:
            albumsTabPath.append(viewPath)
        case .pics:
            picsTabPath.append(viewPath)
        case .more:
            moreTabPath.append(viewPath)
        }
    }

}
