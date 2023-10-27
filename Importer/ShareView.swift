//
//  ShareView.swift
//  Importer
//
//  Created by シン・ジャスティン on 2023/10/15.
//

import SwiftData
import SwiftUI

struct ShareView: View {

    var items: [Any?]

    @State var viewPath: [ViewPath] = []
    @State var progress: Float = 0
    @State var total: Float = 0
    @State var isImporting: Bool = false
    @State var isCompleted: Bool = false
    @State var failedItemCount: Int

    @AppStorage(wrappedValue: 0, "ImageSequence", store: defaults) var runningNumberForImageName: Int

    let actor = DataActor(modelContainer: sharedModelContainer)

    init(items: [Any?], failedItemCount: Int) {
        self.items = items
        self.failedItemCount = failedItemCount
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0.0) {
            if isImporting {
                Group {
                    if !isCompleted {
                        VStack(alignment: .center, spacing: 20.0) {
                            Spacer()
                            Image("Importer.Start")
                                .resizable()
                                .frame(width: 120.0, height: 120.0)
                            Text("Importer.ProgressText")
                                .bold()
                            ProgressView(value: min(progress, total), total: total)
                                .progressViewStyle(.linear)
                            Spacer()
                        }
                    } else {
                        VStack(alignment: .center, spacing: 20.0) {
                            Spacer()
                            if failedItemCount == 0 {
                                Image("Importer.Done")
                                    .resizable()
                                    .frame(width: 120.0, height: 120.0)
                                Text("Importer.DoneText")
                                    .bold()
                            } else {
                                Image("Importer.Error")
                                    .resizable()
                                    .frame(width: 120.0, height: 120.0)
                                Text("Importer.DoneText.WithError.\(failedItemCount)")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                }
                .padding(20.0)
            } else {
                NavigationStack(path: $viewPath) {
                    AlbumsScrollView(title: "Shared.Collection")
                        .navigationDestination(for: ViewPath.self, destination: { viewPath in
                            switch viewPath {
                            case .album(let album):
                                AlbumsScrollView(title: LocalizedStringKey(album.name), parentAlbum: album)
                            default: Color.clear
                            }
                        })
                }
            }
            VStack(alignment: .center, spacing: 16.0) {
                HStack(alignment: .top, spacing: 4.0) {
                    Group {
                        Image(systemName: "info.circle")
                        Text("Importer.Note")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                .padding(10.0)
                .background(.regularMaterial)
                .clipShape(.rect(cornerRadius: 16.0))
                if !isImporting || (isCompleted && failedItemCount > 0) {
                    Button {
                        if isCompleted {
                            close()
                        } else {
                            total = Float(items.count)
                            withAnimation(.snappy.speed(2)) {
                                isImporting = true
                            } completion: {
                                OperationQueue().addOperation {
                                    importItems()
                                }
                            }
                        }
                    } label: {
                        if isCompleted {
                            HStack(alignment: .center, spacing: 4.0) {
                                Text("Shared.Close")
                                    .bold()
                            }
                            .frame(minHeight: 24.0)
                            .frame(maxWidth: .infinity)
                        } else {
                            HStack(alignment: .center, spacing: 4.0) {
                                Image(systemName: "square.and.arrow.down.on.square")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18.0, height: 18.0)
                                Text("Importer.Import")
                                    .bold()
                            }
                            .frame(minHeight: 24.0)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                }
            }
            .padding(20.0)
        }
        .overlay {
            if !isImporting {
                ZStack(alignment: .top) {
                    Color.clear
                    Text("ViewTitle.Importer")
#if targetEnvironment(macCatalyst)
                        .font(.system(size: 13.0))
                        .bold()
                        .padding([.top], 11.0)
#else
                        .font(.system(size: 17.0))
                        .bold()
                        .padding([.top], 18.0)
#endif
                }
            }
        }
    }

    func close() {
        NotificationCenter.default.post(name: NSNotification.Name("close"), object: nil)
    }

    func albumInViewPath() -> Album? {
        if let currentlyDisplayingViewPath = viewPath.last {
            switch currentlyDisplayingViewPath {
            case .album(let album): return album
            default: break
            }
        }
        return nil
    }

    func importItems() {
        let albumID = albumInViewPath()?.persistentModelID
        Task {
            for item in items {
                let illustrationName = "PIC_\(String(format: "%04d", runningNumberForImageName))"
                await importItem(item, to: albumID, named: illustrationName)
                runningNumberForImageName += 1
                await MainActor.run {
                    progress += 1.0
                }
            }
            await MainActor.run {
                withAnimation(.snappy.speed(2)) {
                    isCompleted = true
                } completion: {
                    if failedItemCount == 0 {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            close()
                        }
                    } else {
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    }
                }
            }
        }
    }

    func importItem(_ file: Any?, to albumID: PersistentIdentifier?, named name: String) async {
        if let url = file as? URL, let imageData = try? Data(contentsOf: url),
            let image = UIImage(data: imageData) {
            await importItem(image, to: albumID, named: url.lastPathComponent)
        } else if let image = file as? UIImage {
            if let pngData = image.pngData() {
                await importIllustration(name, data: pngData, to: albumID)
            } else if let jpgData = image.jpegData(compressionQuality: 1.0) {
                await importIllustration(name, data: jpgData, to: albumID)
            } else if let heicData = image.heicData() {
                await importIllustration(name, data: heicData, to: albumID)
            }
        } else {
            failedItemCount += 1
        }
    }

    func importIllustration(_ name: String, data: Data, to albumID: PersistentIdentifier?) async {
        let illustration = Illustration(name: name, data: data)
        await actor.createIllustration(illustration)
        if let albumID {
            await actor.addIllustration(illustration, toAlbumWithIdentifier: albumID)
        }
    }
}
