//
//  RestoreBackupView.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2026/02/24.
//

import SwiftUI

struct RestoreBackupView: View {

    var backupURL: URL
    @Environment(\.dismiss) var dismiss

    @State var isImporting: Bool = false
    @State var isCompleted: Bool = false
    @State var isError: Bool = false
    @State var rootAlbums: [Album] = []

    @State var fileSize: String?

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                if isImporting {
                    StatusView(type: .inProgress, title: "Backup.Restoring")
                } else if isCompleted {
                    StatusView(type: .success, title: "Backup.Restore.Completed")
                } else if isError {
                    StatusView(type: .error, title: "Backup.Restore.Error")
                } else {
                    VStack(alignment: .center, spacing: 16.0) {
                        VStack(alignment: .leading, spacing: 16.0) {
                            VStack(alignment: .leading, spacing: 8.0) {
                                HStack(alignment: .top) {
                                    Text("Shared.FileName")
                                    Spacer()
                                    Text(backupURL.lastPathComponent)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                if let fileSize {
                                    HStack {
                                        Text("Shared.FileSize")
                                        Spacer()
                                        Text(fileSize)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(16.0)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16.0))
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isCompleted || isError {
                    Button {
                        dismiss()
                    } label: {
                        Text("Shared.OK")
                            .bold()
                            .padding(4.0)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .padding(20.0)
                } else {
                    VStack(alignment: .leading, spacing: 8.0) {
                        Button {
                            startImport(targetAlbumID: nil)
                        } label: {
                            Text("Backup.Restore.Merge")
                                .bold()
                                .padding(4.0)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)

                        Text("Backup.Restore.Merge.Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 8.0)

                        Menu {
                            ForEach(rootAlbums) { rootAlbum in
                                AlbumHierarchyMenuItem(
                                    targetAlbum: rootAlbum, excludingAlbumID: ""
                                ) { destinationAlbum in
                                    startImport(targetAlbumID: destinationAlbum.id)
                                }
                            }
                        } label: {
                            Text("Backup.Restore.ToAlbum")
                                .bold()
                                .padding(4.0)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)

                        Text("Backup.Restore.ToAlbum.Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20.0)
                }
            }
            .navigationTitle("ViewTitle.RestoreBackup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !isImporting && !isCompleted && !isError {
                        Button(role: .cancel) {
                            dismiss()
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
        .task {
            rootAlbums = (try? await dataActor.albumsWithCounts(in: nil, sortedBy: .nameAscending)) ?? []
            if let resources = try? backupURL.resourceValues(forKeys: [.fileSizeKey]),
               let size = resources.fileSize {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useAll]
                formatter.countStyle = .file
                fileSize = formatter.string(fromByteCount: Int64(size))
            }
        }
    }

    func startImport(targetAlbumID: String?) {
        withAnimation(.smooth.speed(2.0)) {
            isImporting = true
        } completion: {
            Task {
                do {
                    try await dataActor.importFromBackup(at: backupURL, targetAlbumID: targetAlbumID)
                    await MainActor.run {
                        isImporting = false
                        isCompleted = true
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            dismiss()
                        }
                    }
                } catch {
                    await MainActor.run {
                        isImporting = false
                        isError = true
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                    }
                }
            }
        }
    }
}
