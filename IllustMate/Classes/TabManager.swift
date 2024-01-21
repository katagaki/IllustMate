//
//  TabManager.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import SwiftUI

class TabManager: ObservableObject {
    @Published var selectedTab: TabType = .collection
    @Published var previouslySelectedTab: TabType = .collection
}
