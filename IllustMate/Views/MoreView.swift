//
//  MoreView.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import CloudKitSyncMonitor
import Komponents
import SwiftData
import SwiftUI

struct MoreView: View {

    @EnvironmentObject var navigationManager: NavigationManager
    @Environment(\.modelContext) var modelContext
    @ObservedObject var syncMonitor = SyncMonitor.shared

    @Binding var isReportingProgress: Bool
    @Binding var progressViewText: LocalizedStringKey
    @Binding var currentProgress: Int
    @Binding var total: Int
    @Binding var percentage: Int

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
                } header: {
                    ListSectionHeader(text: "More.Sync")
                        .font(.body)
                } footer: {
                    Text("More.Sync.Description")
                        .font(.body)
                }
                Section {
                    Button {
                        rebuildThumbnails()
                    } label: {
                        Text("More.RebuildThumbnails")
                    }
                    Button(role: .destructive) {
                        deleteData()
                        deleteContents(of: illustrationsFolder)
                        deleteContents(of: thumbnailsFolder)
                        deleteContents(of: importsFolder)
                    } label: {
                        Text("More.DeleteAll")
                    }
                }
            }
            .navigationDestination(for: ViewPath.self) { viewPath in
                switch viewPath {
                case .moreAttributions: LicensesView(licenses: [
                    License(libraryName: "CloudKitSyncMonitor",
                            text:
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
"""),
                License(libraryName: "swiftui-navigation-transitions",
                        text:
"""
MIT License

Copyright (c) 2022 David Roman

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

    func rebuildThumbnails() {
        if let thumbnailsFolder = thumbnailsFolder {
            do {
                let illustrations = try modelContext.fetch(FetchDescriptor<Illustration>())
                progressViewText = "More.RebuildThumbnails.Rebuilding"
                currentProgress = 0
                total = illustrations.count
                percentage = 0
                withAnimation(.easeOut.speed(2)) {
                    isReportingProgress = true
                }
                try FileManager.default.removeItem(at: thumbnailsFolder)
                try FileManager.default.createDirectory(at: thumbnailsFolder,
                                                        withIntermediateDirectories: false)
                Task {
                    await withDiscardingTaskGroup { group in
                        for illustration in illustrations {
                            group.addTask {
                                if let illustrationPath = illustration.illustrationPath(),
                                   let illustrationImage = UIImage(contentsOfFile: illustrationPath),
                                   let thumbnailPath = illustration.thumbnailPath(),
                                   let thumbnailData = Illustration.makeThumbnail(illustrationImage.pngData()) {
                                    FileManager.default.createFile(atPath: thumbnailPath, contents: thumbnailData)
                                }
                                DispatchQueue.main.async {
                                    currentProgress += 1
                                    percentage = Int((Float(currentProgress) / Float(total)) * 100.0)
                                }
                            }
                        }
                    }
                    isReportingProgress = false
                }
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
    }

    func deleteData() {
        try? modelContext.delete(model: Illustration.self, includeSubclasses: true)
        try? modelContext.delete(model: Album.self, includeSubclasses: true)
        do {
            for illustration in try modelContext.fetch(FetchDescriptor<Illustration>()) {
                modelContext.delete(illustration)
            }
            for album in try modelContext.fetch(FetchDescriptor<Album>()) {
                modelContext.delete(album)
            }
        } catch {
            debugPrint(error.localizedDescription)
        }
    }

    func deleteContents(of url: URL?) {
        if let url = url,
           let fileURLs = try? FileManager.default
            .contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            for fileURL in fileURLs {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
}
