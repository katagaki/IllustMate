//
//  MoreOrphansView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/09.
//

import SwiftUI

struct MoreOrphansView: View {

    @Environment(\.modelContext) var modelContext

    @Namespace var orphanTransitionNamespace

    @State var orphans: [String]

    @State var orphanThumbnails: [String: Data] = [:]
    @State var selectedOrphan: String?
    @State var isReimportConfirming: Bool = false

    let phoneColumnConfiguration = [GridItem(.adaptive(minimum: 80.0), spacing: 2.0)]
#if targetEnvironment(macCatalyst)
    let padOrMacColumnConfiguration = [GridItem(.adaptive(minimum: 120.0), spacing: 2.0)]
#else
    let padOrMacColumnConfiguration = [GridItem(.adaptive(minimum: 160.0), spacing: 4.0)]
#endif

#if targetEnvironment(macCatalyst)
    let padOrMacSpacing = 2.0
#else
    let padOrMacSpacing = 4.0
#endif

    var body: some View {
        ScrollView(.vertical) {
            LazyVGrid(
                columns: UIDevice.current.userInterfaceIdiom == .phone ?
                         phoneColumnConfiguration : padOrMacColumnConfiguration,
                spacing: UIDevice.current.userInterfaceIdiom == .phone ? 2.0 : padOrMacSpacing) {
                    ForEach(orphans, id: \.self) { orphan in
                        ZStack(alignment: .center) {
                            Button {
                                selectedOrphan = orphan
                                isReimportConfirming = true
                            } label: {
                                OptionalImage(imageData: orphanThumbnails[orphan])
                            }
                        }
#if targetEnvironment(macCatalyst)
                        .buttonStyle(.borderless)
#else
                        .buttonStyle(.plain)
#endif
                        .aspectRatio(1.0, contentMode: .fill)
                        .contextMenu {
                            Button("Shared.Delete", systemImage: "trash", role: .destructive) {
                                try? FileManager.default.removeItem(at: orphansFolder.appendingPathComponent(orphan))
                                doWithAnimation {
                                    orphans.removeAll(where: { $0 == orphan })
                                }
                            }
                        }
                    }
            }
        }
        .alert("Alert.ReimportOrphan.Title", isPresented: $isReimportConfirming) {
            Button("Shared.Yes") {
                if let selectedOrphan {
                    moveOrphanBack(selectedOrphan)
                }
            }
            Button("Shared.No", role: .cancel) { }
        } message: {
            Text("Alert.ReimportOrphan.Text")
        }
        .task {
            await loadOrphanThumbnails()
        }
        .navigationTitle("ViewTitle.Orphans")
    }

    func loadOrphanThumbnails() async {
        await withDiscardingTaskGroup { group in
            for orphan in orphans {
                group.addTask {
                    do {
                        let filePath = orphansFolder.appendingPathComponent(orphan).path(percentEncoded: false)
                        if let image = UIImage(contentsOfFile: filePath) {
                            orphanThumbnails[orphan] = image.jpegThumbnail(of: 150.0)
                        } else {
                            try FileManager.default.startDownloadingUbiquitousItem(at: URL(filePath: filePath))
                            var isDownloaded: Bool = false
                            while !isDownloaded {
                                if FileManager.default.fileExists(atPath: filePath) {
                                    isDownloaded = true
                                }
                            }
                            if let image = UIImage(contentsOfFile: filePath) {
                                orphanThumbnails[orphan] = image.jpegThumbnail(of: 150.0)
                            }
                        }
                    } catch {
                        debugPrint(error.localizedDescription)
                    }
                }
            }
        }
    }

    func moveOrphanBack(_ fileName: String) {
        if let selectedOrphanImage = UIImage(contentsOfFile: orphansFolder
            .appendingPathComponent(fileName).path(percentEncoded: false)) {
            if let pngData = selectedOrphanImage.pngData() {
                importIllustration(UUID().uuidString, data: pngData)
            } else if let jpgData = selectedOrphanImage.jpegData(compressionQuality: 1.0) {
                importIllustration(UUID().uuidString, data: jpgData)
            } else if let heicData = selectedOrphanImage.heicData() {
                importIllustration(UUID().uuidString, data: heicData)
            }
            try? FileManager.default.removeItem(at: orphansFolder.appendingPathComponent(fileName))
            doWithAnimationAsynchronously {
                orphans.removeAll(where: { $0 == fileName })
            }
        }
    }

    func importIllustration(_ name: String, data: Data) {
        let illustration = Illustration(name: name, data: data)
        illustration.generateThumbnail()
        modelContext.insert(illustration)
    }
}
