//
//  NavigationManager.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Foundation

class NavigationManager: ObservableObject {

    @Published var collectionTabPath: [ViewPath] = []
    @Published var albumsTabPath: [ViewPath] = []
    @Published var illustrationsTabPath: [ViewPath] = []
    @Published var moreTabPath: [ViewPath] = []

    func popAll() {
        collectionTabPath.removeAll()
        albumsTabPath.removeAll()
        illustrationsTabPath.removeAll()
        moreTabPath.removeAll()
    }

    func popToRoot(for tab: TabType) {
        switch tab {
        case .collection:
            collectionTabPath.removeAll()
        case .albums:
            albumsTabPath.removeAll()
        case .illustrations:
            illustrationsTabPath.removeAll()
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
        case .illustrations:
            illustrationsTabPath.append(viewPath)
        case .more:
            moreTabPath.append(viewPath)
        }
    }

}
