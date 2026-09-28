import SwiftUI

struct QandATabView: View {
    var body: some View {
        NavigationStack { FrequentlyAskedQuestionsView() }
    }
}

struct FrequentlyAskedQuestionsView: View {
    @State private var expandedQuestion: Int?

    private let questions: [(String, String)] = [
        ("Can I change my check-in times?", "Yes. Open Settings → Reminder times."),
        ("Can I check in at another time?", "Yes. Tap Extra check-in on Today. It does not count toward the three scheduled check-ins."),
        ("Where are my saved options?", "Open Today → Saved for later. Check-in options last one hour in this demo; bookmarked practices stay saved."),
        ("Is Fitbit connected?", "No real Fitbit is connected. Open Settings → Fitbit to try a demo connection and sync clearly labeled sample data. Fitbit never chooses practices."),
        ("Where are my records?", "Your records are on this device. Open Settings → Study data & export."),
        ("What does the Journey line show?", "Each point averages ratings recorded that day. The line stops where a day has no rating.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(questions.indices, id: \.self) { index in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedQuestion = expandedQuestion == index ? nil : index
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Text(questions[index].0).font(.body.weight(.medium))
                                Spacer(minLength: 4)
                                Image(systemName: expandedQuestion == index ? "chevron.up" : "chevron.down")
                                    .font(.subheadline).foregroundStyle(TendTheme.secondary)
                            }
                            .frame(minHeight: 56, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("qa.question.\(index)")
                        if expandedQuestion == index {
                            Text(questions[index].1).font(.body)
                                .foregroundStyle(TendTheme.secondary)
                                .padding(.bottom, 8)
                        }
                        if index != questions.count - 1 { Divider().overlay(TendTheme.line) }
                    }
                }
                .padding(.horizontal, 16)
                .background(TendTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                NavigationLink { ContactSupportView(kind: .studyTeam) } label: {
                    Label("Ask the study team", systemImage: "bubble.left")
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("qa.contact")
                NavigationLink { ContactSupportView(kind: .technicalSupport) } label: {
                    Label("Technical support", systemImage: "wrench.and.screwdriver")
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("qa.technicalSupport")
            }
            .padding(24)
        }
        .tendScreen()
        .navigationTitle("Q&A")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("qa.screen")
    }
}

struct AccountStatusView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        List {
            Section("On this device") {
                LabeledContent("Name", value: store.data.settings.displayName.isEmpty
                               ? "Not added" : store.data.settings.displayName)
                LabeledContent("Local ID", value: store.data.settings.participantID)
            }
            Section("Account availability") {
                Text("This demo saves on this device. Sign-in and account recovery are not connected.")
                    .font(.body)
            }
        }
        .scrollContentBackground(.hidden)
        .tendScreen()
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
    }
}
