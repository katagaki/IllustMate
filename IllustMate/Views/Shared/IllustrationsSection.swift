//
//  IllustrationsSection.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/03.
//

import Komponents
import SwiftUI

struct IllustrationsSection: View {

    @Environment(\.modelContext) var modelContext
    var illustrations: [Illustration]
    var selectableAlbums: [Album]
    @Binding var isSelectingIllustrations: Bool

    let illustrationsColumnConfiguration = [GridItem(.flexible(), spacing: 2.0),
                                            GridItem(.flexible(), spacing: 2.0),
                                            GridItem(.flexible(), spacing: 2.0),
                                            GridItem(.flexible(), spacing: 2.0)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0.0) {
            HStack(alignment: .center, spacing: 8.0) {
                ListSectionHeader(text: "Albums.Illustrations")
                Spacer()
                Button {
                    withAnimation(.snappy.speed(2)) {
                        isSelectingIllustrations.toggle()
                    }
                } label: {
                    Text("Shared.Select")
                        .padding([.leading, .trailing], 8.0)
                        .padding([.top, .bottom], 4.0)
                        .foregroundStyle(isSelectingIllustrations ? .white : .accent)
                        .background(isSelectingIllustrations ? .accent : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 99))
                }
            }
            .padding([.leading, .trailing], 20.0)
            .padding([.bottom], 6.0)
            Group {
                if !illustrations.isEmpty {
                    LazyVGrid(columns: illustrationsColumnConfiguration, spacing: 2.0) {
                        ForEach(illustrations) { illustration in
                            NavigationLink(value: ViewPath.illustrationViewer(illustration: illustration)) {
                                IllustrationItem(illustration: illustration)
                            }
                            .contextMenu {
                                Menu {
                                    ForEach(selectableAlbums) { album in
                                        Button {
                                            album.addChildIllustration(illustration)
                                        } label: {
                                            Text(album.name)
                                        }
                                    }
                                } label: {
                                    Text("Shared.AddToAlbum")
                                    Image(systemName: "rectangle.stack.badge.plus")
                                }
                                Button(role: .destructive) {
                                    modelContext.delete(illustration)
                                } label: {
                                    Text("Shared.Delete")
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }
                } else {
                    Divider()
                        .padding([.leading], 20.0)
                    Text("Albums.NoIllustrations")
                        .foregroundStyle(.secondary)
                        .padding([.leading, .trailing, .top], 20.0)
                }
            }
        }
    }
}
