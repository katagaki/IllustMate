//
//  MoreExperimentsView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/08.
//

import SwiftUI

struct MoreExperimentsView: View {

    @AppStorage(wrappedValue: false, "DebugThumbnailRegen") var allowPerImageThumbnailRegeneration: Bool
    @AppStorage(wrappedValue: false, "DebugAlbumCoverRes") var showAlbumCoverResolution: Bool
    @AppStorage(wrappedValue: false, "DebugCloudEverywhere") var showCloudStatusEverywhere: Bool
    @AppStorage(wrappedValue: false, "DebugThreadSafety") var useThreadSafeLoading: Bool

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 16.0) {
                    HStack(alignment: .center, spacing: 16.0) {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24.0, height: 24.0)
                            .foregroundStyle(.white)
                        Text("More.Debug.Warning.Title")
                            .font(.title3)
                            .bold()
                            .foregroundStyle(.white)
                    }
                    Text("More.Debug.Warning.Text")
                        .foregroundStyle(.white)
                }
                .padding(20.0)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.red)
            }
            Section {
                Toggle("Experiments.AllowPerImageThumbnailRegeneration", isOn: $allowPerImageThumbnailRegeneration)
                Toggle("Experiments.ShowAlbumCoverResolution", isOn: $showAlbumCoverResolution)
                Toggle("Experiments.ShowCloudStatusEverywhere", isOn: $showCloudStatusEverywhere)
                Toggle("Experiments.UseThreadSafeLoading", isOn: $useThreadSafeLoading)
            }
        }
        .navigationTitle("ViewTitle.Debug")
        .navigationBarTitleDisplayMode(.inline)
    }

}
