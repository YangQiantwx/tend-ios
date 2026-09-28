import SwiftUI

struct AboutTendView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tend is a prototype for an eight-week study with breast cancer survivors.")
                    .font(.body)
                informationCard(
                    "Daily check-ins",
                    "Three a day. Choose movement, mindfulness, both, or neither afterward."
                )
                informationCard(
                    "Your records",
                    "Saved on this device. View or export them in Study data & export."
                )
                informationCard(
                    "Prototype status",
                    "Practice scripts and selection rules await study review."
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .tendScreen()
        .navigationTitle("Study information")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func informationCard(_ title: String, _ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(message).font(.body).foregroundStyle(TendTheme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tendCard()
    }
}
