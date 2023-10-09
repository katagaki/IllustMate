//
//  NavigationManager.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Foundation

class NavigationManager: ObservableObject {

    @Published var collectionTabPath: [ViewPath] = []
    @Published var importerTabPath: [ViewPath] = []
    @Published var illustrationsTabPath: [ViewPath] = []
    @Published var searchTabPath: [ViewPath] = []
    @Published var moreTabPath: [ViewPath] = []

    func popAll() {
        collectionTabPath.removeAll()
        illustrationsTabPath.removeAll()
        importerTabPath.removeAll()
        searchTabPath.removeAll()
        moreTabPath.removeAll()
    }

    func popToRoot(for tab: TabType) {
        switch tab {
        case .collection:
            collectionTabPath.removeAll()
        case .illustrations:
            illustrationsTabPath.removeAll()
        case .importer:
            importerTabPath.removeAll()
        case .search:
            searchTabPath.removeAll()
        case .more:
            moreTabPath.removeAll()
        }
    }

    func push(_ viewPath: ViewPath, for tab: TabType) {
        switch tab {
        case .collection:
            collectionTabPath.append(viewPath)
        case .illustrations:
            illustrationsTabPath.append(viewPath)
        case .importer:
            importerTabPath.append(viewPath)
        case .search:
            searchTabPath.append(viewPath)
        case .more:
            moreTabPath.append(viewPath)
        }
    }

}
