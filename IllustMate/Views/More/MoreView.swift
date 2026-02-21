//
//  MoreView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Komponents
import SwiftUI

struct MoreView: View {

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var navigationManager: NavigationManager
    @Environment(ProgressAlertManager.self) var progressAlertManager

    @State var albumCount: Int = 0
    @State var illustrationCount: Int = 0
    @State var thumbnailCount: Int = 0

    var body: some View {
        NavigationStack(path: $navigationManager.moreTabPath) {
            MoreList(repoName: "katagaki/IllustMate", viewPath: ViewPath.moreAttributions) {
                Section {
                    HStack(alignment: .center, spacing: 8.0) {
                        Text("Shared.Albums")
                        Spacer(minLength: 0)
                        Text("\(albumCount)")
                            .foregroundStyle(.secondary)
                    }
                    HStack(alignment: .center, spacing: 8.0) {
                        Text("Shared.Illustrations")
                        Spacer(minLength: 0)
                        Text("\(illustrationCount)")
                            .foregroundStyle(.secondary)
                    }
                    HStack(alignment: .center, spacing: 8.0) {
                        Text("Shared.Thumbnails")
                        Spacer(minLength: 0)
                        Text("\(thumbnailCount)")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    ListSectionHeader(text: "More.Stats")
                        .font(.body)
                }
#if !targetEnvironment(macCatalyst)
                Section {
                    NavigationLink(value: ViewPath.moreAppIcon) {
                        ListRow(image: "ListIcon.AppIcon",
                                title: "More.Customization.AppIcon")
                    }
                } header: {
                    ListSectionHeader(text: "More.Customization")
                        .font(.body)
                }
#endif
                Section {
//                    NavigationLink(value: ViewPath.moreDebug) {
//                        ListRow(image: "ListIcon.Debug", title: "More.Debug")
//                    }
                    NavigationLink(value: ViewPath.moreTroubleshooting) {
                        ListRow(image: "ListIcon.Troubleshooting", title: "More.Troubleshooting")
                    }
                } header: {
                    ListSectionHeader(text: "More.Advanced")
                        .font(.body)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 26.0, *) {
                        Button(role: .close) {
                            dismiss()
                        }
                    } else {
                        CloseButton {
                            dismiss()
                        }
                    }
                }
            }
            .navigationDestination(for: ViewPath.self) { viewPath in
                switch viewPath {
                case .moreAppIcon: MoreAppIconView()
                case .moreDebug: MoreExperimentsView()
                case .moreTroubleshooting: MoreTroubleshootingView()
                case .moreAttributions: LicensesView(licenses: [
                    License(libraryName: "SQLite.swift", text:
"""
Copyright (c) 2014-2015 Stephen Celis (<stephen@stephencelis.com>)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
""")
                ])
                default: Color.clear
                }
            }
        }
        .task {
            await loadCounts()
        }
    }

    func loadCounts() async {
        let albums = await actor.albumCount()
        let illustrations = await actor.illustrationCount()
        let thumbnails = await actor.thumbnailCount()
        await MainActor.run {
            albumCount = albums
            illustrationCount = illustrations
            thumbnailCount = thumbnails
        }
    }
}
