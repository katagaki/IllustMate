//
//  MoreExperimentsView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/08.
//

import SwiftUI

struct MoreExperimentsView: View {

    @AppStorage(wrappedValue: false, "DebugShowIllustrationIDs") var showIllustrationIDs: Bool
    @AppStorage(wrappedValue: false, "DebugUseNewThumbnailCache") var useNewThumbnailCache: Bool
    @AppStorage(wrappedValue: true, "DebugUseCoreDataThumbnail", store: defaults) var useCoreDataThumbnail: Bool
    @AppStorage(wrappedValue: false, "DebugAllowPerImageThumbnailRegeneration",
                store: defaults) var allowPerImageThumbnailRegeneration: Bool
    @AppStorage(wrappedValue: false, "DebugShowCloudStatusEverywhere") var showCloudStatusEverywhere: Bool

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
                Toggle("Experiments.ShowIllustrationIDs", isOn: $showIllustrationIDs)
            }
            Section {
                Toggle("Experiments.UseNewThumbnailCache", isOn: $useNewThumbnailCache)
                Toggle("Experiments.UseCoreDataThumbnail", isOn: $useCoreDataThumbnail)
                Toggle("Experiments.AllowPerImageThumbnailRegeneration", isOn: $allowPerImageThumbnailRegeneration)
            }
            Section {
                Toggle("Experiments.ShowCloudStatusEverywhere", isOn: $showCloudStatusEverywhere)
            }
        }
        .navigationTitle("ViewTitle.Debug")
        .navigationBarTitleDisplayMode(.inline)
    }

}
