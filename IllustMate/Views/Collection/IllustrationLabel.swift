//
//  IllustrationLabel.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import SwiftUI

struct IllustrationLabel: View {

    var namespace: Namespace.ID

    var illustration: Illustration

    @State var state: CloudImageState = .notReadyForDisplay
    @State var thumbnailImage: UIImage?

    @AppStorage(wrappedValue: true, "DebugUseCoreDataThumbnail", store: defaults) var useCoreDataThumbnail: Bool

    var body: some View {
        ZStack(alignment: .center) {
            if state == .readyForDisplay {
                if let thumbnailImage {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .transition(.opacity.animation(.snappy.speed(2)))
                } else {
                    rectangleWhenError()
                }
            } else {
                rectangleWhenLoading()
            }
        }
        .aspectRatio(1.0, contentMode: .fill)
        .contentShape(Rectangle())
        .onAppear {
            if useCoreDataThumbnail {
                switch state {
                case .notReadyForDisplay:
                    state = .downloading
                    if let image = illustration.thumbnail() {
                        thumbnailImage = image
                    }
                    state = .readyForDisplay
                case .hidden:
                    state = .readyForDisplay
                default: break
                }
            } else {
                switch state {
                case .notReadyForDisplay:
#if !targetEnvironment(macCatalyst)
                    // On iOS, we can use .FILENAME.icloud format to check whether a file is downloaded
                    DispatchQueue.global(qos: .userInteractive).async {
                        do {
                            state = .downloading
                            if let data = try? Data(contentsOf: URL(filePath: illustration.thumbnailPath())),
                               let image = UIImage(data: data) {
                                thumbnailImage = image
                                state = .readyForDisplay
                            } else {
                                if state != .downloading {
                                    try FileManager.default.startDownloadingUbiquitousItem(
                                        at: URL(filePath: illustration.thumbnailPath()))
                                    state = .downloading
                                }
                                while state != .downloaded {
                                    if FileManager.default.fileExists(atPath: illustration.thumbnailPath()) {
                                        state = .downloaded
                                    }
                                }
                                let data = try? Data(contentsOf: URL(filePath: illustration.thumbnailPath()))
                                if let data, let image = UIImage(data: data) {
                                    thumbnailImage = image
                                }
                                state = .readyForDisplay
                            }
                        } catch {
                            debugPrint(error.localizedDescription)
                            state = .readyForDisplay
                        }
                    }
#else
                    // On macOS, such a file doesn't exist,
                    // so we can't do anything about it other than to try to push it to another thread
                    DispatchQueue.global(qos: .userInteractive).async {
                        if let data = try? Data(contentsOf: URL(filePath: illustration.thumbnailPath())) {
                            thumbnailImage = UIImage(data: data)
                        }
                        state = .readyForDisplay
                    }
#endif
                case .hidden:
                    state = .readyForDisplay
                default: break
                }
            }
        }
        .onDisappear {
            state = .hidden
        }
        .draggable(IllustrationTransferable(id: illustration.id)) {
            if let thumbnailImage {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .frame(width: 100.0, height: 100.0)
                    .clipShape(RoundedRectangle(cornerRadius: 8.0))
            }
        }
    }

    @ViewBuilder
    func rectangleWhenLoading() -> some View {
        Rectangle()
            .foregroundStyle(.primary.opacity(0.1))
            .overlay {
                ProgressView()
                    .progressViewStyle(.circular)
            }
    }

    @ViewBuilder
    func rectangleWhenError() -> some View {
        Rectangle()
            .foregroundStyle(.primary.opacity(0.1))
            .overlay {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24.0, height: 24.0)
                    .foregroundStyle(.primary)
                    .symbolRenderingMode(.multicolor)
            }
    }
}
