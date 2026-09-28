import SwiftUI

/// A brief educational preview. Final study education has not been approved.
struct LearningNoteView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Stress, mind, and body")
                    .font(TendTheme.display(34))
                    .accessibilityAddTraits(.isHeader)

                learningSection(
                    "What is stress?",
                    "Stress can show up in thoughts, mood, and the body."
                )
                Divider().overlay(TendTheme.line)
                learningSection(
                    "Why pay attention to the body?",
                    "A check-in helps you notice tension, pain, or sleep changes."
                )
                Divider().overlay(TendTheme.line)
                learningSection(
                    "Why offer movement and mindfulness?",
                    "Choose movement, mindfulness, both, or neither."
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("Read more from the source")
                        .font(.headline)
                    Link(destination: URL(string: "https://www.nimh.nih.gov/health/publications/so-stressed-out-fact-sheet")!) {
                        Label("NIMH: Stress and anxiety", systemImage: "arrow.up.right")
                    }
                    Link(destination: URL(string: "https://www.nccih.nih.gov/health/mind-and-body-practices")!) {
                        Label("NCCIH: Mind and body practices", systemImage: "arrow.up.right")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .tendCard()
            }
            .frame(maxWidth: 600, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .tendScreen()
        .navigationTitle("Learn")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func learningSection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.weight(.semibold))
            Text(body).font(.body).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
