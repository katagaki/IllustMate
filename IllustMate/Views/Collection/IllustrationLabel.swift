//
//  IllustrationLabel.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import SwiftUI

struct IllustrationLabel: View {

    @Environment(ConcurrencyManager.self) private var concurrency
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
        .task {
            if useCoreDataThumbnail {
                switch state {
                case .notReadyForDisplay:
                    state = .downloading
                    concurrency.queue.addOperation {
                        if let image = illustration.thumbnail() {
                            thumbnailImage = image
                        }
                        state = .readyForDisplay
                    }
                default: break
                }
            } else {
                switch state {
                case .notReadyForDisplay:
                    Task.detached(priority: .low) {
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
                default: break
                }
            }
        }
        .onAppear {
            if state == .hidden {
                state = .readyForDisplay
            }
        }
        .onDisappear {
            if state == .readyForDisplay {
                state = .hidden
            }
        }
    }

    @ViewBuilder
    func rectangleWhenLoading() -> some View {
        Rectangle()
            .foregroundStyle(.primary.opacity(0.05))
            .overlay {
                ProgressView()
                    .progressViewStyle(.circular)
            }
    }

    @ViewBuilder
    func rectangleWhenError() -> some View {
        Rectangle()
            .foregroundStyle(.primary.opacity(0.05))
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
