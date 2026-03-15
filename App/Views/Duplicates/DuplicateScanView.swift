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
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .center, spacing: 16.0) {
                Button {
                    Task {
                        await scanManager.scan(scope: scanScope)
                    }
                } label: {
                    Text("Duplicates.StartScan", tableName: "Photos")
                        .bold()
                        .padding(4.0)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            }
            .frame(maxWidth: .infinity)
            .padding(20.0)
        }
    }

    private var scanProgressContent: some View {
        VStack {
            if scanManager.scanPhase == .computingHashes {
                StatusView(type: .inProgress,
                           title: "Duplicates.Scanning.ComputingHashes",
                           tableName: "Photos",
                           currentCount: scanManager.scanProgress,
                           totalCount: scanManager.scanTotal)
            } else {
                StatusView(type: .inProgress,
                           title: "Duplicates.Scanning.Comparing",
                           tableName: "Photos")
            }
        }
    }
}
