//
//  ImportProgressView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/15.
//

import Komponents
import SwiftUI

struct ImportProgressView: View {

    @Environment(\.dismiss) var dismiss

    @Binding var isImportCompleted: Bool
    let importCurrentCount: Int
    let importTotalCount: Int
    let importCompletedCount: Int

    var body: some View {
        NavigationStack {
            VStack(alignment: .center, spacing: 16.0) {
                if !isImportCompleted {
                    StatusView(type: .inProgress, title: "Import.Importing",
                               currentCount: importCurrentCount, totalCount: importTotalCount)
                } else {
                    StatusView(type: .success, title: "Import.Completed.Text.\(importCompletedCount)")
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
                    .padding(.horizontal, 20.0)
                }
            }
            .padding(20.0)
            .navigationTitle("ViewTitle.Import")
            .navigationBarTitleDisplayMode(.inline)
        }
        .phonePresentationDetents([.medium])
        .interactiveDismissDisabled(!isImportCompleted)
    }
}
