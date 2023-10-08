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

    @State var isFileFromCloudReadyForDisplay: Bool = false
    @State var isDownloadTriggered: Bool = false
    @State var shouldDisplay: Bool = true
    @State var thumbnailImage: UIImage?

    var body: some View {
        ZStack(alignment: .center) {
            if shouldDisplay {
                if isFileFromCloudReadyForDisplay {
                    if let thumbnailImage = thumbnailImage {
                        Image(uiImage: thumbnailImage)
                            .resizable()
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
            } else {
                Rectangle()
                    .foregroundStyle(.primary.opacity(0.1))
                    .foregroundStyle(.clear)
            }
        }
        // TODO: Apply nice fade animation when image has loaded
        //       For some reason, it is not possible to do this, a freeze will occur
        .matchedGeometryEffect(id: illustration.id, in: namespace)
        .aspectRatio(1.0, contentMode: .fill)
        .contentShape(Rectangle())
        .onAppear {
            if !isFileFromCloudReadyForDisplay && !isDownloadTriggered {
                Task {
#if !targetEnvironment(macCatalyst)
                    // On iOS, we can use .FILENAME.icloud format to check whether a file is downloaded
                    do {
                        if let thumbnailData = try? Data(contentsOf: URL(filePath: illustration.thumbnailPath())) {
                            let fetchedThumbnailImage = UIImage.byPreparingForDisplay(
                                UIImage(data: thumbnailData)!)
                            thumbnailImage = await fetchedThumbnailImage()
                            isFileFromCloudReadyForDisplay = true
                        } else {
                            isDownloadTriggered = true
                            try FileManager.default.startDownloadingUbiquitousItem(
                                at: URL(filePath: illustration.thumbnailPath()))
                            DispatchQueue.global(qos: .userInitiated).async {
                                var isDownloaded: Bool = false
                                while !isDownloaded {
                                    if FileManager.default.fileExists(atPath: illustration.thumbnailPath()) {
                                        isDownloaded = true
                                    }
                                }
                                thumbnailImage = UIImage(contentsOfFile: illustration.thumbnailPath())
                                DispatchQueue.main.async {
                                    isFileFromCloudReadyForDisplay = true
                                }
                            }
                        }
                    } catch {
                        debugPrint(error.localizedDescription)
                        isFileFromCloudReadyForDisplay = true
                    }
#else
                    // On macOS, such a file doesn't exist, 
                    // so we can't do anything about it other than to try to push it to another thread
                    DispatchQueue.global(qos: .userInitiated).async {
                        if let thumbnailData = try? Data(contentsOf: URL(filePath: illustration.thumbnailPath())) {
                            DispatchQueue.main.async {
                                thumbnailImage = UIImage(data: thumbnailData)
                                isFileFromCloudReadyForDisplay = true
                            }
                        }
                    }
#endif
                }
            }
            shouldDisplay = true
        }
        .onDisappear {
            shouldDisplay = false
        }
        .draggable(IllustrationTransferable(id: illustration.id)) {
            if let thumbnailImage = thumbnailImage {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .frame(width: 100.0, height: 100.0)
                    .clipShape(RoundedRectangle(cornerRadius: 8.0))
            }
        }
    }
}
