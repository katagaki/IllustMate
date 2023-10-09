//
//  MoreOrphansView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/09.
//

import SwiftUI

struct MoreOrphansView: View {

    @Namespace var orphanTransitionNamespace

    var orphans: [String]

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
                        if let image = UIImage(
                            contentsOfFile: orphansFolder.appendingPathComponent(orphan).path(percentEncoded: false)) {
                            Image(uiImage: image)
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
                    }
                    .aspectRatio(1.0, contentMode: .fill)
                }
            }
        }
        .navigationTitle("ViewTitle.Orphans")
    }
}
