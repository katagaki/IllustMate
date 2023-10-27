//
//  MoreOrphansView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/09.
//

import SwiftUI

struct MoreOrphansView: View {

    @Environment(ConcurrencyManager.self) var concurrency

    @Namespace var orphanTransitionNamespace

    @State var orphans: [String]

    @State var orphanThumbnails: [String: Data] = [:]
    @State var selectedOrphan: String?
    @State var isReimportConfirming: Bool = false

    let phoneColumnConfiguration = [GridItem(.adaptive(minimum: 80.0), spacing: 2.0)]
#if targetEnvironment(macCatalyst)
    let padOrMacColumnConfiguration = [GridItem(.adaptive(minimum: 80.0), spacing: 2.0)]
#else
    let padOrMacColumnConfiguration = [GridItem(.adaptive(minimum: 120.0), spacing: 4.0)]
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
        for orphan in orphans {
            let url = URL(filePath: orphansFolder.appendingPathComponent(orphan).path(percentEncoded: false))
            let intent = NSFileAccessIntent.readingIntent(with: url)
            let coordinator = NSFileCoordinator()
            coordinator.coordinate(with: [intent], queue: concurrency.queue) { error in
                if let error {
                    debugPrint(error.localizedDescription)
                } else {
                    if let image = UIImage(contentsOfFile: url.path(percentEncoded: false)) {
                        orphanThumbnails[orphan] = image.jpegThumbnail(of: 120.0)
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
        Task {
            let illustration = Illustration(name: name, data: data)
            await actor.createIllustration(illustration)
        }
    }
}
