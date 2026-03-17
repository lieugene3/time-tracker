import SwiftUI

struct ReportsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Reports")
                    .font(.largeTitle.weight(.bold))

                Text("Charts and the report table land in the next pass. The report ranges and aggregation logic are now wired underneath this screen.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Reports")
    }
}

#Preview {
    NavigationStack {
        ReportsView()
    }
    .modelContainer(SampleData.previewContainer)
}
