import SwiftUI

struct ImportProgressView: View {

    let importCurrentCount: Int
    let importTotalCount: Int

    var body: some View {
        NavigationStack {
            VStack(alignment: .center, spacing: 16.0) {
                StatusView(type: .inProgress, title: .importImporting,
                           currentCount: importCurrentCount, totalCount: importTotalCount)
            }
            .padding(20.0)
            .navigationTitle("ViewTitle.Import")
            .navigationBarTitleDisplayMode(.inline)
        }
        .phonePresentationDetents([.medium])
        .interactiveDismissDisabled()
    }
}
