//
//  ImageMigrationView.swift
//  PicMate
//
//  Blocking, non-dismissable screen shown while image BLOBs are externalized.
//  Cycles the currently-migrating pic every few seconds so there is something
//  to watch during a long run.
//

import SwiftUI
import UIKit

struct ImageMigrationView: View {

    var manager: ImageMigrationManager

    @State private var displayedThumbnail: Data?

    private var progressTotal: Float { Float(max(manager.total, 1)) }

    var body: some View {
        VStack(spacing: 24.0) {
            Spacer()
            previewImage
                .frame(width: 160.0, height: 160.0)
                .clipShape(RoundedRectangle(cornerRadius: 16.0))
                .overlay(
                    RoundedRectangle(cornerRadius: 16.0)
                        .strokeBorder(.separator, lineWidth: 1.0)
                )
            VStack(spacing: 8.0) {
                Text("Migration.Title", tableName: "More")
                    .font(.headline)
                Text("Migration.Subtitle", tableName: "More")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 12.0) {
                ProgressView(value: Float(manager.completed), total: progressTotal)
                    .progressViewStyle(.linear)
                Text("\(manager.completed)/\(manager.total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            Label {
                Text("Migration.Warning", tableName: "More")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(32.0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .interactiveDismissDisabled()
        .task {
            // Refresh the preview every 3 seconds from the latest migrated pic.
            while !Task.isCancelled {
                displayedThumbnail = manager.latestThumbnail
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    @ViewBuilder
    private var previewImage: some View {
        if let displayedThumbnail, let image = UIImage(data: displayedThumbnail) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Rectangle().fill(.quaternary)
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
