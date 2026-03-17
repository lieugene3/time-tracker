import SwiftUI

struct HistoryView: View {
    var body: some View {
        List {
            Section(DateFormatting.dayHeader(.now)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("History is coming in the next pass.")
                        .font(.headline)
                    Text("This scaffold already supports the required tab structure and shared models.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("History")
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(SampleData.previewContainer)
}
