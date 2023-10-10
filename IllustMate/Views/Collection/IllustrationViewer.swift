//
//  IllustrationViewer.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import SwiftUI

struct IllustrationViewer: View {

    var namespace: Namespace.ID

    @State var displayedIllustration: Illustration
    @Binding var illustrationDisplayOffset: CGSize

    @State var isFileFromCloudReadyForDisplay: Bool = false
    @State var displayedImage: UIImage?

    var closeAction: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 16.0) {
            HStack(alignment: .center, spacing: 8.0) {
                Text(displayedIllustration.name)
                    .bold()
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button {
                    closeAction()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24.0, height: 24.0)
                        .foregroundStyle(.primary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            ZStack {
                if isFileFromCloudReadyForDisplay {
                    if let displayedImage {
                        Image(uiImage: displayedImage)
                            .resizable()
                            .scaledToFit()
                            .shadow(color: .black.opacity(0.2), radius: 4.0, x: 0.0, y: 4.0)
                            .transition(.opacity.animation(.snappy.speed(2)))
                    } else {
                        Rectangle()
                            .foregroundStyle(.primary.opacity(0.1))
                            .shadow(color: .black.opacity(0.2), radius: 4.0, x: 0.0, y: 4.0)
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
                        .foregroundStyle(.clear)
                        .overlay {
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .transition(.opacity.animation(.snappy.speed(2)))
            .matchedGeometryEffect(id: displayedIllustration.id, in: namespace)
            .zIndex(1)
            .offset(illustrationDisplayOffset)
            if let displayedImage {
                HStack(alignment: .center, spacing: 2.0) {
                    Group {
                        Text(verbatim: "\(Int(displayedImage.size.width * displayedImage.scale))")
                        Text(verbatim: "×")
                        Text(verbatim: "\(Int(displayedImage.size.height * displayedImage.scale))")
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
            if let image = UIImage(contentsOfFile: displayedIllustration.illustrationPath()) {
                HStack(alignment: .center, spacing: 16.0) {
                    Button("Shared.Copy", systemImage: "doc.on.doc") {
                        UIPasteboard.general.image = image
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    ShareLink(item: Image(uiImage: image),
                              preview: SharePreview(displayedIllustration.name, image: Image(uiImage: image))) {
                        Label("Shared.Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .onAppear {
            Task {
#if !targetEnvironment(macCatalyst)
                // On iOS, we can use .FILENAME.icloud format to check whether a file is downloaded
                do {
                    if let data = try? Data(contentsOf: URL(filePath: displayedIllustration.illustrationPath())) {
                        let fetchedImage = UIImage.byPreparingForDisplay(UIImage(data: data)!)
                        displayedImage = await fetchedImage()
                        isFileFromCloudReadyForDisplay = true
                    } else {
                        try FileManager.default.startDownloadingUbiquitousItem(
                            at: URL(filePath: displayedIllustration.illustrationPath()))
                        DispatchQueue.global(qos: .userInteractive).async {
                            var isDownloaded: Bool = false
                            while !isDownloaded {
                                if FileManager.default.fileExists(atPath: displayedIllustration.illustrationPath()) {
                                    isDownloaded = true
                                }
                            }
                            displayedImage = UIImage(contentsOfFile: displayedIllustration.illustrationPath())
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
                DispatchQueue.global(qos: .userInteractive).async {
                    displayedImage = UIImage(contentsOfFile: displayedIllustration.illustrationPath())
                    DispatchQueue.main.async {
                        isFileFromCloudReadyForDisplay = true
                    }
                }
#endif
            }
        }
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    illustrationDisplayOffset = gesture.translation
                }
                .onEnded { gesture in
                    let width = gesture.translation.width
                    let height = gesture.translation.height
                    let hypotenuse = sqrt((width * width) + (height * height))
                    if hypotenuse > 50.0 {
                        closeAction()
                    } else {
                        withAnimation(.snappy.speed(2)) {
                            illustrationDisplayOffset = .zero
                        }
                    }
                }
        )
    }
}
