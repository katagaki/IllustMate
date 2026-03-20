//
//  PicCarouselStrip.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/20.
//

import SwiftUI

struct PicCarouselStrip: View {

    @Environment(ViewerManager.self) var viewer

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 4.0) {
                    ForEach(Array(viewer.allPics.enumerated()), id: \.element.id) { index, pic in
                        Button {
                            viewer.navigateTo(index: index)
                        } label: {
                            CarouselThumbnail(pic: pic, isSelected: index == viewer.currentIndex)
                        }
                        .buttonStyle(.plain)
                        .id(pic.id)
                    }
                }
                .padding(.horizontal, 20.0)
            }
            .frame(height: 56.0)
            .onChange(of: viewer.currentIndex) { _, _ in
                if let pic = viewer.displayedPic {
                    withAnimation(.smooth) {
                        proxy.scrollTo(pic.id, anchor: .center)
                    }
                }
            }
            .onAppear {
                if let pic = viewer.displayedPic {
                    proxy.scrollTo(pic.id, anchor: .center)
                }
            }
        }
    }
}

struct PicCarouselStripVertical: View {

    @Environment(ViewerManager.self) var viewer

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 4.0) {
                    ForEach(Array(viewer.allPics.enumerated()), id: \.element.id) { index, pic in
                        Button {
                            viewer.navigateTo(index: index)
                        } label: {
                            CarouselThumbnail(pic: pic, isSelected: index == viewer.currentIndex)
                        }
                        .buttonStyle(.plain)
                        .id(pic.id)
                    }
                }
                .padding(.vertical, 8.0)
            }
            .frame(width: 56.0)
            .onChange(of: viewer.currentIndex) { _, _ in
                if let pic = viewer.displayedPic {
                    withAnimation(.smooth) {
                        proxy.scrollTo(pic.id, anchor: .center)
                    }
                }
            }
            .onAppear {
                if let pic = viewer.displayedPic {
                    proxy.scrollTo(pic.id, anchor: .center)
                }
            }
        }
    }
}
