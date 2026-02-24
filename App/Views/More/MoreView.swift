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
    @EnvironmentObject var navigation: NavigationManager

    @State var albumCount: Int = 0
    @State var picCount: Int = 0

    var body: some View {
        NavigationStack(path: $navigation.moreTabPath) {
            MoreList(repoName: "katagaki/IllustMate", viewPath: ViewPath.moreAttributions) {
                Section {
                    Button {
                        let documentsUrl = FileManager.default.urls(
                            for: .documentDirectory, in: .userDomainMask
                        ).first!
#if targetEnvironment(macCatalyst)
                        UIApplication.shared.open(documentsUrl)
#else
                        if let sharedUrl = URL(string: "shareddocuments://\(documentsUrl.path)") {
                            if UIApplication.shared.canOpenURL(sharedUrl) {
                                UIApplication.shared.open(sharedUrl)
                            }
                        }
#endif
                    } label: {
                        ListRow(image: "ListIcon.Files",
                                title: "Shared.OpenFilesApp")
                    }
                    .tint(.primary)
                }
                Section {
                    HStack(alignment: .top) {
                        VStack(spacing: 8.0) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("\(picCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Shared.Pictures")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        VStack(spacing: 8.0) {
                            Image(systemName: "rectangle.stack.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("\(albumCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Shared.Albums")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                } header: {
                    Text("More.Stats")
                }
                Section {
                    Button("More.Backup") {
                        Task {
                            do {
                                _ = try await dataActor.backupDatabase()
                                await MainActor.run {
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                }
                            } catch {
                                await MainActor.run {
                                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                                }
                            }
                        }
                    }
                } header: {
                    Text("More.Data")
                }
                Section {
                    NavigationLink(value: ViewPath.moreTroubleshooting) {
                        ListRow(image: "ListIcon.Troubleshooting", title: "More.Troubleshooting")
                    }
                } header: {
                    Text("More.Advanced")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
            .navigationDestination(for: ViewPath.self) { viewPath in
                switch viewPath {
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
        let albums = await dataActor.albumCount()
        let pics = await dataActor.picCount()
        await MainActor.run {
            albumCount = albums
            picCount = pics
        }
    }
}
