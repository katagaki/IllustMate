//
//  PhotosDuplicateScanView.swift
//  PicMate
//
//  Created on 2026/03/15.
//

import Photos
import SwiftUI

struct PhotosDuplicateScanView: View {

    @Environment(\.dismiss) var dismiss

    @State var scanManager = PhotosDuplicateScanManager()

    let collection: PHAssetCollection

    var body: some View {
        NavigationStack {
            Group {
                if scanManager.isScanning {
                    scanProgressContent
                } else if scanManager.scanPhase == .done {
                    PhotosDuplicateResultsView(scanManager: scanManager)
                } else {
                    scanConfigContent
                }
            }
            .navigationTitle("ViewTitle.DuplicateChecker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !scanManager.isScanning {
                        Button(role: .close) {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !scanManager.isScanning && scanManager.scanPhase == .idle {
                        Button {
                            Task {
                                await scanManager.scan(in: collection)
                            }
                        } label: {
                            Label(
                                String(localized: "Duplicates.StartScan", table: "Photos"),
                                systemImage: "arrow.right"
                            )
                        }
                    }
                }
            }
        }
        .phonePresentationDetents([.medium, .large])
        .interactiveDismissDisabled(scanManager.isScanning)
        .onChange(of: scanManager.isScanning) { _, isScanning in
            UIApplication.shared.isIdleTimerDisabled = isScanning
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private var scanConfigContent: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8.0) {
                    Text("Duplicates.Sensitivity", tableName: "Photos")
                    Slider(value: .init(
                        get: { Double(scanManager.hammingThreshold) },
                        set: { scanManager.hammingThreshold = Int($0) }
                    ), in: 1...15, step: 1)
                    .tint(.accent)
                    HStack {
                        Text("Duplicates.Sensitivity.Strict", tableName: "Photos")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Duplicates.Sensitivity.Loose", tableName: "Photos")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Duplicates.Settings", tableName: "Photos")
            }
        }
    }

    private var scanProgressContent: some View {
        VStack {
            if scanManager.scanPhase == .computingHashes {
                StatusView(type: .inProgress,
                           title: .duplicatesScanningComputingHashes,
                           currentCount: scanManager.scanProgress,
                           totalCount: scanManager.scanTotal)
            } else {
                StatusView(type: .inProgress,
                           title: .duplicatesScanningComparing)
            }
        }
    }
}
