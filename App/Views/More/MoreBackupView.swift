import Foundation
import SwiftUI

struct MoreBackupView: View {

    enum Phase: Equatable {
        case preparing
        case confirming
        case exporting
        case completed
        case failed
    }

    @Environment(\.dismiss) var dismiss
    var destinationURL: URL
    var collectionID: String
    var libraryName: String

    @State private var phase: Phase = .preparing
    @State private var estimatedBytes: Int64 = 0
    @State private var availableBytes: Int64 = 0
    @State private var progressCurrent: Int = 0
    @State private var progressTotal: Int = 0
    @State private var failureTitle: StatusView.StatusTitle =
        .custom("Backup.Error.Destination", tableName: "More")
    @State private var freeSpaceKnown: Bool = true

    private var hasEnoughSpace: Bool {
        !freeSpaceKnown
            || availableBytes >= DataActor.requiredFreeSpace(forBackupPayload: estimatedBytes)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .preparing:
                    StatusView(type: .inProgress,
                               title: .custom("Backup.Preparing", tableName: "More"))
                case .confirming:
                    confirmation
                case .exporting:
                    StatusView(type: .inProgress, title: .backupExporting,
                               currentCount: progressCurrent, totalCount: progressTotal)
                case .completed:
                    completion(title: .backupExportCompleted, isError: false)
                case .failed:
                    completion(title: failureTitle, isError: true)
                }
            }
            .padding(20.0)
            .navigationTitle("ViewTitle.Backup")
            .navigationBarTitleDisplayMode(.inline)
        }
        .phonePresentationDetents([.medium])
        .interactiveDismissDisabled(phase == .exporting || phase == .preparing)
        .task { await prepare() }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private var confirmation: some View {
        VStack(alignment: .center, spacing: 16.0) {
            Spacer()
            Text("Backup.Confirm.Title", tableName: "More")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Backup.Confirm.Message", tableName: "More")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(spacing: 6.0) {
                summaryRow("Backup.Confirm.Size", value: byteString(estimatedBytes))
                if freeSpaceKnown {
                    summaryRow("Backup.Confirm.Available", value: byteString(availableBytes))
                }
            }
            .font(.callout)
            if freeSpaceKnown && !hasEnoughSpace {
                Text("Backup.Error.InsufficientSpace", tableName: "More")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button {
                Task { await runBackup() }
            } label: {
                Text("Backup.Start", tableName: "More")
                    .bold().padding(4.0).frame(maxWidth: .infinity)
            }
            .tint(.accent)
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .disabled(!hasEnoughSpace)
            Button { dismiss() } label: {
                Text("Shared.Cancel").padding(4.0).frame(maxWidth: .infinity)
            }
            .tint(.secondary)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
    }

    private func summaryRow(_ label: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(label, tableName: "More").foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
    }

    @ViewBuilder
    private func completion(title: StatusView.StatusTitle, isError: Bool) -> some View {
        VStack(alignment: .center, spacing: 16.0) {
            StatusView(type: isError ? .error : .success, title: title)
            Button { dismiss() } label: {
                Text("Shared.OK").bold().padding(4.0).frame(maxWidth: .infinity)
            }
            .tint(.accent)
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
        }
    }

    private func byteString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func prepare() async {
        guard phase == .preparing else { return }
        let dataActor = DataActor(collectionID: collectionID)
        let cid = collectionID
        let estimate = await dataActor.backupEstimate(sizeProvider: { picID in
            await OriginalsManager.shared.originalSize(picID: picID, in: cid)
        })
        let accessed = destinationURL.startAccessingSecurityScopedResource()
        let values = try? destinationURL.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey
        ])
        if accessed { destinationURL.stopAccessingSecurityScopedResource() }
        estimatedBytes = estimate.bytes
        if let important = values?.volumeAvailableCapacityForImportantUsage {
            availableBytes = important
            freeSpaceKnown = true
        } else if let plain = values?.volumeAvailableCapacity {
            availableBytes = Int64(plain)
            freeSpaceKnown = true
        } else {
            freeSpaceKnown = false
        }
        withAnimation(.smooth.speed(2.0)) { phase = .confirming }
    }

    private func runBackup() async {
        phase = .exporting
        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = false }
        let dataActor = DataActor(collectionID: collectionID)
        let cid = collectionID
        do {
            try await dataActor.backupDatabase(
                to: destinationURL,
                libraryName: libraryName,
                originalProvider: { picID in
                    await OriginalsManager.shared.fetchOriginal(picID: picID, in: cid)
                },
                sizeProvider: { picID in
                    await OriginalsManager.shared.originalSize(picID: picID, in: cid)
                },
                progress: { current, total in
                    progressCurrent = current
                    progressTotal = total
                }
            )
            withAnimation(.smooth.speed(2.0)) { phase = .completed }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch let error as BackupError {
            failureTitle = title(for: error)
            withAnimation(.smooth.speed(2.0)) { phase = .failed }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } catch {
            failureTitle = .custom(LocalizedStringKey(error.localizedDescription))
            withAnimation(.smooth.speed(2.0)) { phase = .failed }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func title(for error: BackupError) -> StatusView.StatusTitle {
        switch error {
        case .insufficientSpace:
            .custom("Backup.Error.InsufficientSpace", tableName: "More")
        case .originalUnavailable:
            .custom("Backup.Error.Incomplete", tableName: "More")
        case .destinationInaccessible:
            .custom("Backup.Error.Destination", tableName: "More")
        }
    }
}
