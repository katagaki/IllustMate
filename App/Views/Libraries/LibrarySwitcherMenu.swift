import SwiftUI
import TipKit
import UIKit

struct LibrarySwitcherMenu: View {

    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var navigation: NavigationManager

    @AppStorage("PhotosModeEnabled", store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate"))
    var isPhotosModeEnabled: Bool = false
    @AppStorage("PhotosNestedAlbumsEnabled", store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate"))
    var isNestedAlbumsEnabled: Bool = false

    @Binding var isLibraryManagerPresented: Bool

    var body: some View {
        Menu {
            Section(String(localized: "Libraries.Section.PicMate", table: "Libraries")) {
                ForEach(libraryManager.libraries) { library in
                    Button {
                        guard library.id != libraryManager.currentLibrary.id else { return }
                        libraryManager.switchLibrary(to: library)
                        navigation.signalDataDeleted()
                    } label: {
                        if library.id == libraryManager.currentLibrary.id {
                            Label(libraryManager.displayName(for: library),
                                  systemImage: "checkmark")
                        } else {
                            Text(libraryManager.displayName(for: library))
                        }
                    }
                }
                Button {
                    isLibraryManagerPresented = true
                } label: {
                    Label(String(localized: "Libraries.Manage", table: "Libraries"),
                          systemImage: "slider.horizontal.3")
                }
            }
            .disabled(isPhotosModeEnabled)
            Section(String(localized: "Libraries.Section.Photos", table: "Libraries")) {
                Toggle(isOn: $isPhotosModeEnabled) {
                    Label(String(localized: "PhotosMode", table: "More"),
                          systemImage: "photo.on.rectangle")
                }
                if isPhotosModeEnabled {
                    Toggle(isOn: $isNestedAlbumsEnabled) {
                        Label(String(localized: "Experiments.NestedAlbums", table: "More"),
                              systemImage: "list.bullet.indent")
                    }
                    Button {
                        UIPasteboard.general.string = "▶︎ "
                    } label: {
                        Label(String(localized: "Experiments.NestedAlbums.CopyPrefix", table: "More"),
                              systemImage: "doc.on.doc")
                    }
                    .disabled(!isNestedAlbumsEnabled)
                }
            }
        } label: {
            if isPhotosModeEnabled {
                Label(String(localized: "PhotosMode", table: "More"),
                      systemImage: "photo.on.rectangle")
            } else {
                Label(libraryManager.displayName(for: libraryManager.currentLibrary),
                      systemImage: "square.stack.3d.up")
            }
        }
        .popoverTip(LibrariesTip(), arrowEdge: .top)
    }
}
