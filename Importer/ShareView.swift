//
//  ShareView.swift
//  Importer
//
//  Created by シン・ジャスティン on 2023/10/15.
//

import SwiftData
import SwiftUI

struct ShareView: View {

    let modelContext = ModelContext(sharedModelContainer)

    @State var viewPath: [ViewPath] = []
    var albums: [Album]
    var items: [Any?]
    @State var progress: Float = 0
    @State var total: Float = 0
    @State var isImporting: Bool = false
    @State var isCompleted: Bool = false
    @State var failedItemCount: Int

    init(items: [Any?], failedItemCount: Int) {
        self.items = items
        self.failedItemCount = failedItemCount
        do {
            albums = try modelContext.fetch(FetchDescriptor<Album>(
                predicate: #Predicate { $0.parentAlbum == nil },
                sortBy: [SortDescriptor(\.name)]))
        } catch {
            debugPrint(error.localizedDescription)
            albums = []
        }
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
                    AlbumsScrollView(title: "Shared.Collection", albums: albums)
                        .navigationDestination(for: ViewPath.self, destination: { viewPath in
                            switch viewPath {
                            case .album(let album): AlbumsScrollView(title: LocalizedStringKey(album.name),
                                                                     albums: album.albums())
                            default: Color.clear
                            }
                        })
                }
            }
            VStack(alignment: .center, spacing: 16.0) {
                Text("Importer.Note")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if !isImporting || (isCompleted && failedItemCount > 0) {
                    Button {
                        if isCompleted {
                            close()
                        } else {
                            total = Float(items.count)
                            withAnimation(.snappy.speed(2)) {
                                isImporting = true
                            } completion: {
                                DispatchQueue.global(qos: .background).async {
                                    let modelContext = ModelContext(sharedModelContainer)
                                    for item in items {
                                        importItem(modelContext, item)
                                        DispatchQueue.main.async {
                                            progress += 1.0
                                        }
                                    }
                                    withAnimation(.snappy.speed(2)) {
                                        isCompleted = true
                                    } completion: {
                                        if failedItemCount == 0 {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                close()
                                            }
                                        }
                                    }
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
                        .padding([.top], 14.0)
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

    func importItem(_ context: ModelContext, _ file: Any?, name: String = UUID().uuidString) {
        if let url = file as? URL, let imageData = try? Data(contentsOf: url),
            let image = UIImage(data: imageData) {
            importItem(context, image, name: url.lastPathComponent)
        } else if let image = file as? UIImage {
            if let pngData = image.pngData() {
                importIllustration(context, name, data: pngData)
            } else if let jpgData = image.jpegData(compressionQuality: 1.0) {
                importIllustration(context, name, data: jpgData)
            } else if let heicData = image.heicData() {
                importIllustration(context, name, data: heicData)
            }
        } else {
            failedItemCount += 1
        }
    }

    func importIllustration(_ context: ModelContext, _ name: String, data: Data) {
        let illustration = Illustration(name: name, data: data)
        if let selectedAlbum = albumInViewPath() {
            illustration.containingAlbum = selectedAlbum
        }
        if let thumbnailData = UIImage(data: data)?.jpegThumbnail(of: 150.0) {
            let thumbnail = Thumbnail(data: thumbnailData)
            illustration.cachedThumbnail = thumbnail
        }
        modelContext.insert(illustration)
    }
}
