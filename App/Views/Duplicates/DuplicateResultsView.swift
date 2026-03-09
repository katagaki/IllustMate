//
//  DuplicateResultsView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/09.
//

import Komponents
import SwiftUI

struct DuplicateResultsView: View {

    var scanManager: DuplicateScanManager

    var body: some View {
        if scanManager.duplicateGroups.isEmpty {
            ContentUnavailableView {
                Label("Duplicates.NoDuplicatesFound", systemImage: "checkmark.circle")
            } description: {
                Text("Duplicates.NoDuplicatesFound.Message")
            }
        } else {
            List {
                ForEach(scanManager.duplicateGroups) { group in
                    DuplicateGroupSection(group: group) { deletedIDs in
                        scanManager.removePics(withIDs: deletedIDs)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
        }
    }
}

// MARK: - Group Section

struct DuplicateGroupSection: View {

    let group: DuplicateGroup
    var onDelete: (Set<String>) -> Void

    @State var selectedForDeletion: Set<String> = []
    @State var comparisonViewerManager = ViewerManager()
    @State var isShowingComparison: Bool = false
    @State var isConfirmingDelete: Bool = false

    var body: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12.0) {
                    ForEach(group.pics) { pic in
                        DuplicateDetailCard(
                            pic: pic,
                            isSelectedForDeletion: selectedForDeletion.contains(pic.id)
                        ) {
                            withAnimation(.smooth.speed(2.0)) {
                                if selectedForDeletion.contains(pic.id) {
                                    selectedForDeletion.remove(pic.id)
                                } else {
                                    if selectedForDeletion.count < group.pics.count - 1 {
                                        selectedForDeletion.insert(pic.id)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4.0)
                .padding(.horizontal, 18.0)
            }
            .listRowInsets(EdgeInsets(top: 14.0, leading: 0, bottom: 14.0, trailing: 0))
            Button("Duplicates.CompareInCarousel") {
                let firstPic = group.pics[0]
                comparisonViewerManager.setDisplay(firstPic, in: group.pics) {
                    isShowingComparison = true
                }
            }
            if !selectedForDeletion.isEmpty {
                Button("Duplicates.DeleteSelected.\(selectedForDeletion.count)",
                       role: .destructive) {
                    isConfirmingDelete = true
                }
            }
        } header: {
            Text("Duplicates.GroupCount.\(group.pics.count)")
        }
        .confirmationDialog(
            "Shared.DeleteConfirmation.Pic.\(selectedForDeletion.count)",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Shared.Yes", role: .destructive) {
                Task {
                    for picID in selectedForDeletion {
                        await DataActor.shared.deletePic(withID: picID)
                        await HashActor.shared.deleteHash(forPicWithID: picID)
                    }
                    await MainActor.run {
                        withAnimation(.smooth.speed(2.0)) {
                            onDelete(selectedForDeletion)
                        }
                    }
                    selectedForDeletion = []
                }
            }
            Button("Shared.No", role: .cancel) {}
        }
        .navigationDestination(isPresented: $isShowingComparison) {
            PicViewer(pic: group.pics[0])
                .environment(comparisonViewerManager)
        }
    }
}
