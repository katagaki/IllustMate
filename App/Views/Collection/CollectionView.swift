//
//  CollectionView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/03.
//

import Komponents
import Photos
import SwiftUI

struct CollectionView: View {

    @EnvironmentObject var navigation: NavigationManager
    @EnvironmentObject var libraryManager: LibraryManager
    @Environment(ViewerManager.self) var viewer
    @Environment(PhotosViewerManager.self) var photosViewer
    @State var isMoreViewPresenting: Bool = false
    @State var isLibraryManagerPresented: Bool = false
    @Namespace var sheetNamespace

    @AppStorage("PhotosModeEnabled",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var isPhotosModeEnabled: Bool = false

    var body: some View {
        NavigationStack(path: $navigation.collectionTabPath) {
            Group {
                if isPhotosModeEnabled {
                    PhotosCollectionView()
                } else {
                    AlbumView()
                }
            }
            .toolbar {
                if UIDevice.current.userInterfaceIdiom == .phone {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Button {
                            isMoreViewPresenting = true
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                        .matchedTransitionSource(id: "moreView", in: sheetNamespace)
                    }
                    if !isPhotosModeEnabled {
                        ToolbarSpacer(.fixed, placement: .topBarLeading)
                        ToolbarItemGroup(placement: .topBarLeading) {
                            Button {
                                isLibraryManagerPresented = true
                            } label: {
                                Label(libraryManager.displayName(for: libraryManager.currentLibrary),
                                      systemImage: "square.stack.3d.up")
                            }
                            .matchedTransitionSource(id: "libraryManager", in: sheetNamespace)
                        }
                    }
                }
            }
            .sheet(isPresented: $isMoreViewPresenting) {
                MoreView()
                    .phonePresentationDetents([.medium, .large])
                    .navigationTransition(.zoom(sourceID: "moreView", in: sheetNamespace))
            }
            .sheet(isPresented: $isLibraryManagerPresented) {
                LibraryManagerSheet()
                    .environmentObject(libraryManager)
                    .environmentObject(navigation)
                    .navigationTransition(.zoom(sourceID: "libraryManager", in: sheetNamespace))
            }
            .navigationDestination(for: ViewPath.self, destination: { viewPath in
              switch viewPath {
              case .album(let album):
                  AlbumView(currentAlbum: album)
              case .picViewer(let namespace):
                  if let displayedPic = viewer.displayedPic {
                      if #available(iOS 18, *) {
                          PicViewer(pic: displayedPic)
                          .navigationTransition(.zoom(sourceID: viewer.displayedPicID,
                                                      in: namespace))
                      } else {
                          PicViewer(pic: displayedPic)
                      }
                  }
              case .photosFolder(let wrapper):
                  PhotosFolderView(folder: wrapper.collectionList)
              case .photosAlbum(let wrapper):
                  PhotosAlbumContentView(collection: wrapper.collection)
              case .photosAssetViewer(let wrapper, let namespace):
                  if #available(iOS 18, *) {
                      PhotosAssetViewer(asset: wrapper.asset)
                          .navigationTransition(.zoom(
                              sourceID: wrapper.asset.localIdentifier,
                              in: namespace))
                  } else {
                      PhotosAssetViewer(asset: wrapper.asset)
                  }
              case .picViewerRestore:
                  if let displayedPic = viewer.displayedPic {
                      PicViewer(pic: displayedPic)
                  }
              case .photosAssetViewerRestore:
                  if let displayedAsset = photosViewer.displayedAsset {
                      PhotosAssetViewer(asset: displayedAsset)
                  }
              default: Color.clear
              }
            })
        }
        .onChange(of: isPhotosModeEnabled) { _, _ in
            navigation.collectionTabPath.removeAll()
        }
    }
}
