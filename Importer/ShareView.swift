import SwiftUI

struct ShareView: View {

    var itemsManager: SharedItemsManager

    @State var viewPath: [ViewPath] = []
    @State var progress: Float = 0
    @State var total: Float = 0
    @State var isImporting: Bool = false
    @State var isCompleted: Bool = false

    var body: some View {
        VStack(alignment: .center, spacing: 0.0) {
            if isImporting {
                Group {
                    if !isCompleted {
                        VStack(alignment: .center, spacing: 16.0) {
                            Text("Import.Importing")
                            ProgressView(value: min(progress, total), total: total)
                                .progressViewStyle(.linear)
                        }
                    } else {
                        VStack(alignment: .center, spacing: 16.0) {
                            if itemsManager.failedItemCount == 0 {
                                Image(systemName: "checkmark.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 64.0, height: 64.0)
                                    .symbolRenderingMode(.multicolor)
                                Text("Import.Completed.Text.\(Int(total))")
                            } else {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 64.0, height: 64.0)
                                    .symbolRenderingMode(.multicolor)
                                Text("Importer.DoneText.WithError.\(itemsManager.failedItemCount)")
                            }
                        }
                    }
                }
                .padding(20.0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                NavigationStack(path: $viewPath) {
                    AlbumsScrollView(title: "Shared.Collection")
                        .navigationDestination(for: ViewPath.self, destination: { viewPath in
                            if case .album(let album) = viewPath {
                                AlbumsScrollView(title: LocalizedStringKey(album.name), parentAlbum: album)
                            } else {
                                Color.clear
                            }
                        })
                }
            }
            if !isImporting || (isCompleted && itemsManager.failedItemCount > 0) {
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

                    Button {
                        if isCompleted {
                            close()
                        } else {
                            total = Float(itemsManager.items.count)
                            withAnimation(.smooth.speed(2)) {
                                isImporting = true
                            } completion: {
                                Task {
                                    importItems()
                                }
                            }
                        }
                    } label: {
                        if isCompleted {
                            Text("Shared.OK")
                                .bold()
                                .padding(4.0)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Import.StartImport")
                                .bold()
                                .padding(4.0)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .tint(.green)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .disabled(!itemsManager.isLoaded || itemsManager.items.isEmpty)
                }
                .padding(20.0)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .overlay {
            if !itemsManager.isLoaded {
                ZStack(alignment: .center) {
                    Color(uiColor: .systemBackground)
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }

            if !isImporting && itemsManager.isLoaded {
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
                .allowsHitTesting(false)
            }
        }
    }

    func close() {
        NotificationCenter.default.post(name: NSNotification.Name("close"), object: nil)
    }

    func albumInViewPath() -> Album? {
        if let currentlyDisplayingViewPath = viewPath.last,
           case .album(let album) = currentlyDisplayingViewPath {
            return album
        }
        return nil
    }

    func importItems() {
        let albumID = albumInViewPath()?.id
        Task {
            for item in itemsManager.items {
                await importItem(item, to: albumID, named: Pic.newFilename())
                await MainActor.run {
                    progress += 1.0
                }
            }
            await MainActor.run {
                withAnimation(.smooth.speed(2)) {
                    isCompleted = true
                } completion: {
                    if itemsManager.failedItemCount == 0 {
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

    func importItem(_ file: Any?, to albumID: String?, named name: String) async {
        if let url = file as? URL, let imageData = try? Data(contentsOf: url),
            let image = UIImage(data: imageData) {
            await importItem(image, to: albumID, named: url.lastPathComponent)
        } else if let image = file as? UIImage {
            if let pngData = image.pngData() {
                await importPic(name, data: pngData, to: albumID)
            } else if let jpgData = image.jpegData(compressionQuality: 1.0) {
                await importPic(name, data: jpgData, to: albumID)
            } else if let heicData = image.heicData() {
                await importPic(name, data: heicData, to: albumID)
            }
        } else {
            await MainActor.run {
                itemsManager.failedItemCount += 1
            }
        }
    }

    func importPic(_ name: String, data: Data, to albumID: String?) async {
        await DataActor.shared.createPic(name, data: data, inAlbumWithID: albumID)
    }
}
