//
//  RebuildThumbnailsProgressView.swift
//  PicMate
//
//  Created by Claude on 2026/03/18.
//

import SwiftUI

struct RebuildThumbnailsProgressView: View {

    @Binding var currentCount: Int
    @Binding var totalCount: Int

    var body: some View {
        StatusView(type: .inProgress, title: .troubleshootingRebuildingThumbnails,
                   currentCount: currentCount, totalCount: totalCount)
    }
}
