//
//  MoreExperimentsView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/08.
//

import Komponents
import SwiftUI

struct MoreExperimentsView: View {

    @AppStorage(wrappedValue: false, "DebugCloudEverywhere") var showCloudStatusEverywhere: Bool
    @AppStorage(wrappedValue: false, "DebugThumbnailRegen") var allowPerImageThumbnailRegeneration: Bool
    @AppStorage(wrappedValue: false, "DebugThumbnailTools") var showAdvancedThumbnailOptions: Bool
    @AppStorage(wrappedValue: false, "DebugAlbumCoverRes") var showAlbumCoverResolution: Bool
    @AppStorage(wrappedValue: false, "DebugAdvancedFiles") var showAdvancedFileOptions: Bool
    @AppStorage(wrappedValue: false, "DebugDeleteWithoutFile") var deleteWithoutFile: Bool
    @AppStorage(wrappedValue: true, "DebugAllAnimsOff") var disableAllAnimations: Bool
    @AppStorage(wrappedValue: false, "DebugSlowAnims") var slowDownAnimations: Bool

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
                Toggle("Experiments.ShowCloudStatusEverywhere", isOn: $showCloudStatusEverywhere)
            } header: {
                ListSectionHeader(text: "Experiments.Section.Cloud")
                    .font(.body)
            }
            Section {
                Toggle("Experiments.AllowPerImageThumbnailRegeneration", isOn: $allowPerImageThumbnailRegeneration)
                Toggle("Experiments.ShowAdvancedThumbnailOptions", isOn: $showAdvancedThumbnailOptions)
                Toggle("Experiments.ShowAlbumCoverResolution", isOn: $showAlbumCoverResolution)
            } header: {
                ListSectionHeader(text: "Experiments.Section.Imaging")
                    .font(.body)
            }
            Section {
                Toggle("Experiments.ShowAdvancedFileOptions", isOn: $showAdvancedFileOptions)
                Toggle("Experiments.DeleteIllustrationWithoutFile", isOn: $deleteWithoutFile)
            } header: {
                ListSectionHeader(text: "Experiments.Section.Filesystem")
                    .font(.body)
            }
            Section {
                Toggle("Experiments.DisableAllAnimations", isOn: $disableAllAnimations)
                Toggle("Experiments.SlowDownAnimations", isOn: $slowDownAnimations)
            } header: {
                ListSectionHeader(text: "Experiments.Section.Animations")
                    .font(.body)
            }
        }
        .navigationTitle("ViewTitle.Debug")
        .navigationBarTitleDisplayMode(.inline)
    }

}
