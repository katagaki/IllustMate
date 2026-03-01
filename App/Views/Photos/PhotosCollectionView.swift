//
//  PhotosCollectionView.swift
//  PicMate
//
//  Created on 2026/02/26.
//

import Photos
import SwiftUI

struct PhotosCollectionView: View {

    @Environment(PhotosManager.self) var photosManager
    @EnvironmentObject var navigation: NavigationManager

    @Namespace var namespace

    @State var items: [PHCollectionItem] = []
    @State var rootAssets: [PHAsset] = []
    @State var hasFetched: Bool = false

    @AppStorage(wrappedValue: ViewStyle.grid, "AlbumViewStyle",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var albumStyleState: ViewStyle
    @AppStorage(wrappedValue: 3, "AlbumColumnCount",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var albumColumnCount: Int
    @AppStorage(wrappedValue: 4, "PicColumnCount",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var picColumnCount: Int

    var body: some View {
        Group {
            switch photosManager.authorizationStatus {
            case .authorized, .limited:
                collectionContent
            case .denied, .restricted:
                photosAccessDeniedView
            default:
                ProgressView()
                    .onAppear {
                        photosManager.requestAuthorization()
                    }
            }
        }
        .navigationTitle(String(localized: "ViewTitle.Photos"))
    }

    // MARK: - Collection Content

    private var collectionContent: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0.0) {
                photosAlbumsSection
                if !rootAssets.isEmpty {
                    Spacer()
                        .frame(height: 20.0)
                    photosPicsSection
                }
            }
            .padding([.top], 20.0)
        }
        .onAppear {
            if !hasFetched {
                items = photosManager.fetchTopLevelCollections()
                rootAssets = photosManager.fetchAssetsNotInAnyAlbum()
                hasFetched = true
            }
        }
    }

    private var photosAlbumsSection: some View {
        Group {
            SectionHeader(title: "Albums.Albums", count: items.count) {
                Picker("Albums.Style",
                       selection: $albumStyleState.animation(.smooth.speed(2))) {
                    Label("Albums.Style.Grid", systemImage: "square.grid.2x2")
                        .tag(ViewStyle.grid)
                    Label("Albums.Style.List", systemImage: "list.bullet")
                        .tag(ViewStyle.list)
                    Label("Albums.Style.Carousel", systemImage: "rectangle.on.rectangle")
                        .tag(ViewStyle.carousel)
                }
                if albumStyleState == .grid {
                    Picker("Shared.GridSize",
                           systemImage: "square.grid.2x2",
                           selection: $albumColumnCount.animation(.smooth.speed(2.0))) {
                        Text("Shared.GridSize.2")
                            .tag(2)
                        Text("Shared.GridSize.3")
                            .tag(3)
                        Text("Shared.GridSize.4")
                            .tag(4)
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding(EdgeInsets(top: 0.0, leading: 20.0, bottom: 6.0, trailing: 20.0))
            if !items.isEmpty {
                PhotosAlbumsSection(items: items, style: $albumStyleState)
            } else if hasFetched {
                Text("Albums.NoAlbums")
                    .foregroundStyle(.secondary)
                    .padding(20.0)
            }
        }
    }

    private var photosPicsSection: some View {
        Group {
            SectionHeader(title: "Albums.Pics", count: rootAssets.count) {
                Picker("Shared.GridSize",
                       systemImage: "square.grid.2x2",
                       selection: $picColumnCount.animation(.smooth.speed(2.0))) {
                    Text("Shared.GridSize.3")
                        .tag(3)
                    Text("Shared.GridSize.4")
                        .tag(4)
                    Text("Shared.GridSize.5")
                        .tag(5)
                    Text("Shared.GridSize.8")
                        .tag(8)
                }
                .pickerStyle(.menu)
            }
            .padding(EdgeInsets(top: 0.0, leading: 20.0, bottom: 6.0, trailing: 20.0))
            PhotosAssetsGrid(namespace: namespace, assets: rootAssets)
        }
    }

    // MARK: - Access Denied

    private var photosAccessDeniedView: some View {
        VStack(spacing: 16.0) {
            Image(systemName: "photo.badge.exclamationmark")
                .resizable()
                .scaledToFit()
                .frame(width: 64.0, height: 64.0)
                .foregroundStyle(.secondary)
            Text("Import.PhotosAccessDenied")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Import.OpenSettings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
        .padding(40.0)
    }
}
