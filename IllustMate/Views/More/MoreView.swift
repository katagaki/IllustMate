//
//  MoreView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Komponents
import SwiftData
import SwiftUI

struct MoreView: View {

    @EnvironmentObject var navigationManager: NavigationManager
    @Environment(ProgressAlertManager.self) var progressAlertManager

    @AppStorage(wrappedValue: false, "DebugAdvancedFiles") var showAdvancedFileOptions: Bool

    var body: some View {
        NavigationStack(path: $navigationManager.moreTabPath) {
            MoreList(repoName: "katagaki/IllustMate", viewPath: ViewPath.moreAttributions) {
                Section {
                    NavigationLink(value: ViewPath.moreDataManagement) {
                        ListRow(image: "ListIcon.DataManagement", title: "More.DataManagement")
                    }
                    if showAdvancedFileOptions {
                        NavigationLink(value: ViewPath.moreFileManagement) {
                            ListRow(image: "ListIcon.FileManagement", title: "More.FileManagement")
                        }
                    }
                } header: {
                    ListSectionHeader(text: "More.General")
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
            .navigationDestination(for: ViewPath.self) { viewPath in
                switch viewPath {
                case .moreDataManagement: MoreDataManagementView()
                case .moreFileManagement: MoreFileManagementView()
                case .moreAppIcon: MoreAppIconView()
                case .moreDebug: MoreExperimentsView()
                case .moreOrphans(let orphans): MoreOrphansView(orphans: orphans)
                case .moreTroubleshooting: MoreTroubleshootingView()
                case .moreAttributions: LicensesView(licenses: [
                    // swiftlint:disable line_length
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
                    // swiftlint:enable line_length
                default: Color.clear
                }
            }
        }
    }
}
