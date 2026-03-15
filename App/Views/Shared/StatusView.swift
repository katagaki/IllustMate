//
//  StatusView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/02/24.
//

import SwiftUI

struct StatusView: View {

    var type: StatusType
    var title: StatusTitle
    var message: LocalizedStringKey?
    var currentCount: Int?
    var totalCount: Int?

    enum StatusType {
        case inProgress
        case success
        case error
    }

    enum StatusTitle {
        // Photos table
        case duplicatesScanningComputingHashes
        case duplicatesScanningComparing

        // Import table
        case importImporting
        case importCompleted(count: Int)

        // More table
        case backupExporting
        case backupExportCompleted
        case troubleshootingRebuildingThumbnails
        case troubleshootingFreeingUpSpace
        case backupRestoring
        case backupRestoreCompleted
        case backupRestoreError

        // Custom (for dynamic strings like error messages)
        case custom(LocalizedStringKey, tableName: String? = nil)

        var text: Text {
            switch self {
            case .duplicatesScanningComputingHashes:
                Text("Duplicates.Scanning.ComputingHashes", tableName: "Photos")
            case .duplicatesScanningComparing:
                Text("Duplicates.Scanning.Comparing", tableName: "Photos")
            case .importImporting:
                Text("Import.Importing", tableName: "Import")
            case .importCompleted(let count):
                Text("Import.Completed.Text.\(count)", tableName: "Import")
            case .backupExporting:
                Text("Backup.Exporting", tableName: "More")
            case .backupExportCompleted:
                Text("Backup.Export.Completed", tableName: "More")
            case .troubleshootingRebuildingThumbnails:
                Text("Troubleshooting.RebuildThumbnails.Rebuilding", tableName: "More")
            case .troubleshootingFreeingUpSpace:
                Text("Troubleshooting.FreeUpSpace.Freeing", tableName: "More")
            case .backupRestoring:
                Text("Backup.Restoring", tableName: "More")
            case .backupRestoreCompleted:
                Text("Backup.Restore.Completed", tableName: "More")
            case .backupRestoreError:
                Text("Backup.Restore.Error", tableName: "More")
            case .custom(let key, let tableName):
                Text(key, tableName: tableName)
            }
        }
    }

    var body: some View {
        VStack(alignment: .center, spacing: 20.0) {
            Spacer()
            switch type {
            case .inProgress:
                if let currentCount, let totalCount {
                    VStack(alignment: .center, spacing: 16.0) {
                        title.text
                            .bold()
                            .frame(maxWidth: .infinity)
                        ProgressView(value: Float(currentCount), total: Float(totalCount))
                            .progressViewStyle(.linear)
                    }
                } else {
                    VStack(alignment: .center, spacing: 16.0) {
                        ProgressView()
                            .progressViewStyle(.circular)
                        title.text
                            .bold()
                            .frame(maxWidth: .infinity)
                    }
                }
            case .success:
                VStack(alignment: .center, spacing: 16.0) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64.0, height: 64.0)
                        .symbolRenderingMode(.multicolor)
                    title.text
                        .bold()
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    if let message {
                        Text(message)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
            case .error:
                VStack(alignment: .center, spacing: 16.0) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64.0, height: 64.0)
                        .symbolRenderingMode(.multicolor)
                    title.text
                        .bold()
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    if let message {
                        Text(message)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            Spacer()
        }
        .padding(20.0)
        .frame(maxWidth: .infinity)
    }
}
