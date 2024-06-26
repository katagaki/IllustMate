//
//  MoreView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import CloudKitSyncMonitor
import Komponents
import SwiftData
import SwiftUI

struct MoreView: View {

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var navigationManager: NavigationManager
    @Environment(ProgressAlertManager.self) var progressAlertManager
    @ObservedObject var syncMonitor = SyncMonitor.shared

    @Query var illustrations: [Illustration]
    @Query var albums: [Album]
    @Query var thumbnails: [Thumbnail]

    var body: some View {
        NavigationStack(path: $navigationManager.moreTabPath) {
            MoreList(repoName: "katagaki/IllustMate", viewPath: ViewPath.moreAttributions) {
                Section {
                    VStack(alignment: .center, spacing: 16.0) {
                        Group {
                            if syncMonitor.syncStateSummary.isBroken {
                                Image(systemName: "xmark.icloud.fill")
                                    .resizable()
                                    .foregroundStyle(.red)
                            } else if syncMonitor.syncStateSummary.inProgress {
                                Image(systemName: "arrow.triangle.2.circlepath.icloud.fill")
                                    .resizable()
                                    .foregroundStyle(.primary)
                            } else {
                                switch syncMonitor.syncStateSummary {
                                case .notStarted, .succeeded:
                                    Image(systemName: "checkmark.icloud.fill")
                                        .resizable()
                                        .foregroundStyle(.green)
                                case .noNetwork:
                                    Image(systemName: "bolt.horizontal.icloud.fill")
                                        .resizable()
                                        .foregroundStyle(.orange)
                                default:
                                    Image(systemName: "exclamationmark.icloud.fill")
                                        .resizable()
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                        .symbolRenderingMode(.multicolor)
                        .scaledToFit()
                        .frame(width: 64.0, height: 64.0)
                        Group {
                            if syncMonitor.syncStateSummary.isBroken {
                                Text("More.Sync.State.Error")
                            } else if syncMonitor.syncStateSummary.inProgress {
                                Text("More.Sync.State.InProgress")
                            } else {
                                switch syncMonitor.syncStateSummary {
                                case .notStarted, .succeeded:
                                    Text("More.Sync.State.Synced")
                                case .noNetwork:
                                    Text("More.Sync.State.NoNetwork")
                                default:
                                    Text("More.Sync.State.NotSyncing")
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .alignmentGuide(.listRowSeparatorLeading, computeValue: { _ in
                        return 0.0
                    })
                    HStack(alignment: .center, spacing: 8.0) {
                        Text("Shared.Albums")
                        Spacer(minLength: 0)
                        Text("\(albums.count)")
                            .foregroundStyle(.secondary)
                    }
                    HStack(alignment: .center, spacing: 8.0) {
                        Text("Shared.Illustrations")
                        Spacer(minLength: 0)
                        Text("\(illustrations.count)")
                            .foregroundStyle(.secondary)
                    }
                    HStack(alignment: .center, spacing: 8.0) {
                        Text("Shared.Thumbnails")
                        Spacer(minLength: 0)
                        Text("\(thumbnails.count)")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    ListSectionHeader(text: "More.Sync")
                        .font(.body)
                } footer: {
                    if isCloudSyncEnabled {
                        Text("More.Sync.Description")
                            .font(.body)
                    }
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
                    NavigationLink(value: ViewPath.moreDebug) {
                        ListRow(image: "ListIcon.Debug", title: "More.Debug")
                    }
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
                    CloseButton {
                        dismiss()
                    }
                }
            }
            .navigationDestination(for: ViewPath.self) { viewPath in
                switch viewPath {
                case .moreAppIcon: MoreAppIconView()
                case .moreDebug: MoreExperimentsView()
                case .moreOrphans(let orphans): MoreOrphansView(orphans: orphans)
                case .moreTroubleshooting: MoreTroubleshootingView()
                case .moreAttributions: LicensesView(licenses: [
                    License(libraryName: "CloudKitSyncMonitor", text:
"""
Copyright (c) 2020 Grant Grueninger

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
""")])
                default: Color.clear
                }
            }
        }
    }
}
