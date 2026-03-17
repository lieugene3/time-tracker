import SwiftUI

struct HomeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("No current activity")
                    .font(.title2.weight(.semibold))

                Text("Choose what you're doing now.")
                    .foregroundStyle(.secondary)

                ForEach(ActivityCategory.allCases) { category in
                    Label(category.displayName, systemImage: category.supportsSubActivities ? "book.closed" : "circle.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding()
        }
        .navigationTitle("Home")
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .modelContainer(SampleData.previewContainer)
}
