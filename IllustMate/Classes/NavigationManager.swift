//
//  NavigationManager.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Foundation

class NavigationManager: ObservableObject {

    @Published var collectionViewPath: [ViewPath] = []
    @Published var moreTabPath: [ViewPath] = []

    func popAll() {
        collectionViewPath.removeAll()
        moreTabPath.removeAll()
    }

    func popToRoot(for tab: TabType) {
        switch tab {
        case .collection:
            collectionViewPath.removeAll()
        case .more:
            moreTabPath.removeAll()
        }
    }

    func push(_ viewPath: ViewPath, for tab: TabType) {
        switch tab {
        case .collection:
            collectionViewPath.append(viewPath)
        case .more:
            moreTabPath.append(viewPath)
        }
    }

}
