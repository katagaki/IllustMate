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
                                if let imageData = orphanThumbnails[orphan],
                                   let image = UIImage(data: imageData) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .transition(.opacity.animation(.snappy.speed(2)))
                                } else {
                                    Rectangle()
                                        .foregroundStyle(.primary.opacity(0.1))
                                }
                            }
#if targetEnvironment(macCatalyst)
                            .buttonStyle(.borderless)
#else
                            .buttonStyle(.plain)
#endif
                        }
                        .aspectRatio(1.0, contentMode: .fill)
                        .contextMenu {
                            Button("Shared.Delete", systemImage: "trash", role: .destructive) {
                                try? FileManager.default.removeItem(at: orphansFolder.appendingPathComponent(orphan))
                                withAnimation(.snappy.speed(2)) {
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
            loadOrphanThumbnails()
        }
        .navigationTitle("ViewTitle.Orphans")
    }

    func loadOrphanThumbnails() {
        DispatchQueue.global(qos: .userInteractive).async {
            for orphan in orphans {
                let fullOrphanFilePath = orphansFolder
                    .appendingPathComponent(orphan).path(percentEncoded: false)
                if let image = UIImage(contentsOfFile: fullOrphanFilePath) {
                    orphanThumbnails[orphan] = image.jpegThumbnail(of: 150.0)
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
            withAnimation(.snappy.speed(2)) {
                orphans.removeAll(where: { $0 == fileName })
            }
        }
    }

    func importIllustration(_ name: String, data: Data) {
        let illustration = Illustration(name: name, data: data)
        modelContext.insert(illustration)
    }
}
