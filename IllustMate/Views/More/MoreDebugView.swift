//
//  MoreDebugView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/08.
//

import SwiftUI

struct MoreDebugView: View {

    @AppStorage(wrappedValue: false, "DebugShowIllustrationIDs") var showIllustrationIDs: Bool
    @AppStorage(wrappedValue: false, "DebugUseNewThumbnailCache") var useNewThumbnailCache: Bool

    var body: some View {
        List {
            Section {
                Toggle("More.Debug.ShowIllustrationIDs", isOn: $showIllustrationIDs)
                Toggle("More.Debug.UseNewThumbnailCache", isOn: $useNewThumbnailCache)
            }
        }
        .navigationTitle("ViewTitle.Debug")
        .navigationBarTitleDisplayMode(.inline)
    }

}
