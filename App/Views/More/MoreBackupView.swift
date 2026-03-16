//
//  MoreBackupView.swift
//  PicMate
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
                if isExporting {
                    StatusView(type: .inProgress, title: .backupExporting)
                } else if isCompleted {
                    StatusView(type: .success, title: .backupExportCompleted)
                } else if let error {
                    StatusView(type: .error, title: .custom(LocalizedStringKey(error)))
                }
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
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
                    .padding(20.0)
                }
            }
        }
        .task {
            do {
                try await DataActor.shared.backupDatabase(to: destinationURL)
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
        .phonePresentationDetents([.medium])
        .interactiveDismissDisabled()
    }
}
