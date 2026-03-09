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

    var preselectedAlbum: Album?

    @State var selectedAlbum: Album?
    @State var scanEntireCollection: Bool = true
    @State var albums: [Album] = []

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

    private var albumForScan: Album? {
        if preselectedAlbum != nil {
            return preselectedAlbum
        }
        return scanEntireCollection ? nil : selectedAlbum
    }

    private var scanConfigContent: some View {
        List {
            if preselectedAlbum == nil {
                Section {
                    Toggle("Duplicates.ScanEntireCollection", isOn: $scanEntireCollection)
                    if !scanEntireCollection {
                        ForEach(albums) { album in
                            Button {
                                selectedAlbum = album
                            } label: {
                                HStack {
                                    Text(album.name)
                                    Spacer()
                                    if selectedAlbum?.id == album.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.accent)
                                    }
                                }
                            }
                            .tint(.primary)
                        }
                    }
                } header: {
                    Text("Duplicates.Scope")
                }
            }
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
                        await scanManager.scan(album: albumForScan)
                    }
                }
                .disabled(preselectedAlbum == nil && !scanEntireCollection && selectedAlbum == nil)
            }
        }
        .task {
            if preselectedAlbum == nil {
                do {
                    albums = try await DataActor.shared.albumsWithCounts(sortedBy: .nameAscending)
                } catch {
                    debugPrint(error.localizedDescription)
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
