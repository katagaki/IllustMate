import SwiftUI
import UIKit

struct SuggestionGroup: Identifiable {
    let albumID: String
    let albumName: String
    let items: [EntitySuggestion]

    var id: String { albumID }
}

struct IntelligentSortResultsView: View {

    @Environment(\.dismiss) var dismiss

    var sortManager: IntelligentSortManager

    @State private var isConfirmingMove: Bool = false

    private var needsReview: [EntitySuggestion] {
        sortManager.suggestions.filter { ($0.topMatch?.confidence ?? .none) == .none }
    }

    private var suggestionGroups: [SuggestionGroup] {
        var order: [String] = []
        var grouped: [String: [EntitySuggestion]] = [:]
        var names: [String: String] = [:]
        for suggestion in sortManager.suggestions {
            guard let top = suggestion.topMatch, top.confidence != .none else { continue }
            if grouped[top.albumID] == nil {
                order.append(top.albumID)
                names[top.albumID] = top.albumName
            }
            grouped[top.albumID, default: []].append(suggestion)
        }
        let groups = order.map { albumID in
            SuggestionGroup(
                albumID: albumID,
                albumName: names[albumID] ?? "",
                items: (grouped[albumID] ?? []).sorted {
                    ($0.topMatch?.distance ?? 1) < ($1.topMatch?.distance ?? 1)
                }
            )
        }
        return groups.sorted {
            ($0.items.first?.topMatch?.distance ?? 1) < ($1.items.first?.topMatch?.distance ?? 1)
        }
    }

    private var hasStrongMatches: Bool {
        sortManager.suggestions.contains { $0.topMatch?.confidence == .strong }
    }

    var body: some View {
        Group {
            if sortManager.targetAlbumCount == 0 {
                ContentUnavailableView {
                    Label(String(localized: "Sort.NoTargets", table: "Photos"),
                          systemImage: "rectangle.stack.badge.xmark")
                } description: {
                    Text("Sort.NoTargets.Message", tableName: "Photos")
                }
            } else if sortManager.suggestions.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "Sort.NoPics", table: "Photos"),
                          systemImage: "photo.on.rectangle")
                } description: {
                    Text("Sort.NoPics.Message", tableName: "Photos")
                }
            } else {
                resultsList
            }
        }
    }

    private var resultsList: some View {
        List {
            ForEach(suggestionGroups) { group in
                Section {
                    ForEach(group.items) { suggestion in
                        SuggestionRow(suggestion: suggestion, dataActor: sortManager.dataActor)
                    }
                } header: {
                    HStack {
                        Text(verbatim: group.albumName)
                        Spacer()
                        Button(String(localized: "Sort.AcceptAllInGroup", table: "Photos")) {
                            withAnimation(.smooth.speed(2.0)) {
                                for item in group.items {
                                    item.selectedAlbumID = item.topMatch?.albumID
                                }
                            }
                        }
                        .font(.caption)
                        .textCase(nil)
                    }
                }
            }
            if !needsReview.isEmpty {
                Section {
                    ForEach(needsReview) { suggestion in
                        SuggestionRow(suggestion: suggestion, dataActor: sortManager.dataActor)
                    }
                } header: {
                    Text("Sort.NeedsReview", tableName: "Photos")
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(
                    String(localized: "Sort.MovePics.\(sortManager.pendingMoveCount)", table: "Photos"),
                    systemImage: "tray.full"
                ) {
                    isConfirmingMove = true
                }
                .tint(.accent)
                .disabled(sortManager.pendingMoveCount == 0)
            }
            if hasStrongMatches {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "Sort.AcceptAllStrong", table: "Photos")) {
                        withAnimation(.smooth.speed(2.0)) {
                            sortManager.acceptAllStrongMatches()
                        }
                    }
                }
            }
        }
        .alert(
            String(
                localized: """
                Sort.MoveConfirmation.\
                \(sortManager.pendingMoveCount)-\(sortManager.pendingDestinationCount)
                """,
                table: "Photos"
            ),
            isPresented: $isConfirmingMove
        ) {
            Button("Shared.Yes") {
                Task {
                    await sortManager.commit()
                    let moves = sortManager.committedMoves
                    let collectionID = sortManager.collectionID
                    let message = await IntelligentSortManager.moveSummaryMessage(
                        for: moves, collectionID: collectionID
                    )
                    ToastManager.shared.show(ToastItem(
                        message: message,
                        undo: moves.isEmpty ? nil : {
                            await IntelligentSortManager.revert(moves, collectionID: collectionID)
                        }
                    ))
                    dismiss()
                }
            }
            Button("Shared.No", role: .cancel) {}
        }
    }
}

// MARK: - Suggestion Row

struct SuggestionRow: View {

    @Bindable var suggestion: EntitySuggestion
    var dataActor: DataActor

    private var chosenMatch: AlbumMatch? {
        guard let selected = suggestion.selectedAlbumID else { return nil }
        return suggestion.matches.first { $0.albumID == selected }
    }

    private var isIncluded: Bool { suggestion.selectedAlbumID != nil }

    var body: some View {
        HStack(spacing: 12.0) {
            PicLabel(pic: suggestion.pic)
                .frame(width: 52.0, height: 52.0)
                .clipShape(.rect(cornerRadius: 8.0))

            VStack(alignment: .leading, spacing: 3.0) {
                Text(suggestion.pic.name)
                    .lineLimit(1)
                confidenceLabel
                if let chosen = chosenMatch {
                    Text("Sort.MovesTo.\(chosen.albumName)", tableName: "Photos")
                        .font(.caption)
                        .foregroundStyle(.accent)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8.0)

            if let medoidID = chosenMatch?.medoidPicID ?? suggestion.topMatch?.medoidPicID {
                MedoidThumbnail(picID: medoidID, dataActor: dataActor)
                    .frame(width: 40.0, height: 40.0)
                    .clipShape(.rect(cornerRadius: 6.0))
            }

            destinationMenu
        }
        .opacity(isIncluded || !suggestion.isUnanalyzable ? 1.0 : 0.6)
    }

    @ViewBuilder
    private var confidenceLabel: some View {
        if suggestion.isUnanalyzable {
            Label(String(localized: "Sort.Unanalyzable", table: "Photos"),
                  systemImage: "questionmark.square.dashed")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            let confidence = suggestion.topMatch?.confidence ?? .none
            Label(confidenceText(confidence), systemImage: confidenceIcon(confidence))
                .font(.caption)
                .foregroundStyle(confidenceColor(confidence))
        }
    }

    private var destinationMenu: some View {
        Menu {
            ForEach(suggestion.matches) { match in
                Button {
                    suggestion.selectedAlbumID = match.albumID
                } label: {
                    if suggestion.selectedAlbumID == match.albumID {
                        Label(match.albumName, systemImage: "checkmark")
                    } else {
                        Text(verbatim: match.albumName)
                    }
                }
            }
            if !suggestion.matches.isEmpty {
                Divider()
            }
            Button(role: .destructive) {
                suggestion.selectedAlbumID = nil
            } label: {
                Label(String(localized: "Sort.Skip", table: "Photos"), systemImage: "xmark")
            }
        } label: {
            Image(systemName: isIncluded ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isIncluded ? Color.accent : Color.secondary)
        }
        .disabled(suggestion.matches.isEmpty)
    }

    private func confidenceText(_ confidence: SortConfidence) -> String {
        switch confidence {
        case .strong: String(localized: "Sort.Confidence.Strong", table: "Photos")
        case .likely: String(localized: "Sort.Confidence.Likely", table: "Photos")
        case .weak: String(localized: "Sort.Confidence.Weak", table: "Photos")
        case .none: String(localized: "Sort.NoSuggestion", table: "Photos")
        }
    }

    private func confidenceIcon(_ confidence: SortConfidence) -> String {
        switch confidence {
        case .strong: "checkmark.seal.fill"
        case .likely: "checkmark.circle"
        case .weak: "questionmark.circle"
        case .none: "minus.circle"
        }
    }

    private func confidenceColor(_ confidence: SortConfidence) -> Color {
        switch confidence {
        case .strong: .green
        case .likely: .accent
        case .weak: .orange
        case .none: .secondary
        }
    }
}

// MARK: - Medoid Thumbnail

struct MedoidThumbnail: View {

    let picID: String
    var dataActor: DataActor

    @State private var image: UIImage?

    var body: some View {
        Rectangle()
            .fill(.primary.opacity(0.05))
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .task(id: picID) {
                if let data = await dataActor.thumbnailData(forPicWithID: picID) {
                    image = UIImage(data: data)
                }
            }
    }
}
