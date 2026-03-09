//
//  DuplicateScanView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/09.
//

import Komponents
import SwiftUI
import UIKit

struct DuplicateScanView: View {

    @Environment(\.dismiss) var dismiss

    @State var scanManager = DuplicateScanManager()

    var scanScope: DuplicateScanManager.ScanScope

    var body: some View {
        NavigationStack {
            Group {
                if scanManager.isScanning {
                    scanProgressContent
                } else if scanManager.scanPhase == .done {
                    DuplicateResultsView(scanManager: scanManager)
                } else {
                    scanConfigContent
                }
            }
            .navigationTitle("ViewTitle.DuplicateChecker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !scanManager.isScanning {
                        Button(role: .close) {
                            dismiss()
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(scanManager.isScanning)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private var scanConfigContent: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8.0) {
                    Text("Duplicates.Sensitivity")
                    Slider(value: .init(
                        get: { Double(scanManager.hammingThreshold) },
                        set: { scanManager.hammingThreshold = Int($0) }
                    ), in: 1...15, step: 1)
                    HStack {
                        Text("Duplicates.Sensitivity.Strict")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Duplicates.Sensitivity.Loose")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Duplicates.Settings")
            }
            Section {
                Button("Duplicates.StartScan") {
                    Task {
                        await scanManager.scan(scope: scanScope)
                    }
                }
            }
        }
    }

    private var scanProgressContent: some View {
        VStack {
            if scanManager.scanPhase == .computingHashes {
                StatusView(type: .inProgress,
                           title: "Duplicates.Scanning.ComputingHashes",
                           currentCount: scanManager.scanProgress,
                           totalCount: scanManager.scanTotal)
            } else {
                StatusView(type: .inProgress,
                           title: "Duplicates.Scanning.Comparing")
            }
        }
    }
}
