//
//  MoreDebugView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/08.
//

import SwiftUI

struct MoreDebugView: View {

    @AppStorage(wrappedValue: false, "DebugShowIllustrationIDs") var showIllustrationIDs: Bool

    var body: some View {
        List {
            Section {
                Toggle("More.Debug.ShowIllustrationIDs", isOn: $showIllustrationIDs)
            }
        }
        .navigationTitle("ViewTitle.Debug")
        .navigationBarTitleDisplayMode(.inline)
    }

}
