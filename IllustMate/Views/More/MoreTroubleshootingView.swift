//
//  MoreTroubleshootingView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/09.
//

import SwiftData
import SwiftUI

struct MoreTroubleshootingView: View {

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var navigationManager: NavigationManager

    @State var isDeleteConfirming: Bool = false

    var body: some View {
        List {
            Section {
                Button("More.Troubleshooting.DeleteAll", role: .destructive) {
                    isDeleteConfirming = true
                }
            }
        }
        .alert("Alert.DeleteAll.Title", isPresented: $isDeleteConfirming) {
            Button(role: .destructive) {
                deleteData()
                deleteContents(of: illustrationsFolder)
                deleteContents(of: thumbnailsFolder)
                deleteContents(of: importsFolder)
                navigationManager.popAll()
            } label: {
                Text("Shared.Yes")
            }
            Button(role: .cancel) { } label: {
                Text("Shared.No")
            }
        } message: {
            Text("Alert.DeleteAll.Text")
        }
        .navigationTitle("ViewTitle.Troubleshooting")
        .navigationBarTitleDisplayMode(.inline)
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
        if let url, let fileURLs = try? FileManager.default
            .contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: []) {
            for fileURL in fileURLs {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
}
