import SwiftUI

enum BackupFormat: String, CaseIterable, Identifiable {
    case archive
    case folders

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .archive: "Backup.Format.Archive"
        case .folders: "Backup.Format.Folders"
        }
    }

    var description: LocalizedStringKey {
        switch self {
        case .archive: "Backup.Format.Archive.Description"
        case .folders: "Backup.Format.Folders.Description"
        }
    }
}
