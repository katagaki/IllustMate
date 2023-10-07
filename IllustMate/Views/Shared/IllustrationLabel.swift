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
                            Image(systemName: "icloud.and.arrow.down.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24.0, height: 24.0)
                                .foregroundStyle(.primary)
                                .symbolRenderingMode(.multicolor)
                        }
                }
            } else {
                Rectangle()
                    .foregroundStyle(.clear)
            }
        }
        .matchedGeometryEffect(id: illustration.id, in: namespace)
        .aspectRatio(1.0, contentMode: .fill)
        .contentShape(Rectangle())
        .onAppear {
            if !isFileFromCloudReadyForDisplay {
                Task {
                    let fetchedThumbnailImage = UIImage(contentsOfFile: illustration.thumbnailPath())
                    thumbnailImage = fetchedThumbnailImage
                    isFileFromCloudReadyForDisplay = true
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
