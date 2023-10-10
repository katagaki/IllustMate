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

    @AppStorage(wrappedValue: false, "DebugUseCoreDataThumbnail") var useCoreDataThumbnail: Bool

    var body: some View {
        ZStack(alignment: .center) {
            if useCoreDataThumbnail {
                if let thumbnail = illustration.thumbnail() {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .transition(.opacity.animation(.snappy.speed(2)))
                } else {
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
            } else {
                if state == .readyForDisplay {
                    if let thumbnailImage {
                        Image(uiImage: thumbnailImage)
                            .resizable()
                            .transition(.opacity.animation(.snappy.speed(2)))
                        // IMPORTANT: Do NOT move this transition to after matchedGeometryEffect, as it
                        // will cause CATASTROPHIC freezes!
                    } else {
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
                } else {
                    Rectangle()
                        .foregroundStyle(.primary.opacity(0.1))
                        .overlay {
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                }
            }
        }
        .matchedGeometryEffect(id: illustration.id, in: namespace)
        .aspectRatio(1.0, contentMode: .fill)
        .contentShape(Rectangle())
        .task {
            if !useCoreDataThumbnail {
                switch state {
                case .notReadyForDisplay:
#if !targetEnvironment(macCatalyst)
                    // On iOS, we can use .FILENAME.icloud format to check whether a file is downloaded
                    DispatchQueue.global(qos: .userInteractive).async {
                        do {
                            state = .downloading
                            if let thumbnailData = try? Data(contentsOf: URL(filePath: illustration.thumbnailPath())),
                               let image = UIImage(data: thumbnailData) {
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
                        if let thumbnailData = try? Data(contentsOf: URL(filePath: illustration.thumbnailPath())) {
                            let data = try? Data(contentsOf: URL(filePath: illustration.thumbnailPath()))
                            if let data {
                                thumbnailImage = UIImage(data: data)
                            }
                            isFileFromCloudReadyForDisplay = true
                        }
                    }
#endif
                case .hidden:
                    state = .readyForDisplay
                default: break
                }
            }
        }
        .onDisappear {
            if !useCoreDataThumbnail {
                state = .hidden
            }
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
}
