//
//  MoreBackupView.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2026/02/24.
//

import SwiftUI

struct MoreBackupView: View {

    @Environment(\.dismiss) var dismiss
    var destinationURL: URL

    @State var isExporting: Bool = true
    @State var isCompleted: Bool = false
    @State var error: String?

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .center, spacing: 16.0) {
                    if isExporting {
                        ProgressView()
                            .progressViewStyle(.circular)
                        Text("Backup.Exporting")
                            .bold()
                    } else if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64.0, height: 64.0)
                            .symbolRenderingMode(.multicolor)
                        Text("Backup.Export.Completed")
                    } else if let error {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64.0, height: 64.0)
                            .symbolRenderingMode(.multicolor)
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .navigationTitle("ViewTitle.Backup")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if isCompleted || error != nil {
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
                }
            }
        }
        .task {
            do {
                try await dataActor.backupDatabase(to: destinationURL)
                await MainActor.run {
                    withAnimation(.smooth.speed(2.0)) {
                        isExporting = false
                        isCompleted = true
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    withAnimation(.smooth.speed(2.0)) {
                        isExporting = false
                        self.error = error.localizedDescription
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }
}
