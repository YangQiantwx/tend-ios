import SwiftUI

struct PracticeDirectorySection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Practices")
            ForEach(PracticeCategory.allCases, id: \.self) { category in
                NavigationLink { PracticeCategoryListView(category: category) } label: {
                    categoryRow(category)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("today.category.\(category.rawValue)")
            }
        }
    }

    private func categoryRow(_ category: PracticeCategory) -> some View {
        HStack(spacing: 16) {
            Image(systemName: category == .movement ? "figure.walk" : "brain.head.profile")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(category == .movement ? TendTheme.sea : TendTheme.terracotta)
                .frame(width: 64, height: 64)
                .background(category == .movement ? TendTheme.sage : TendTheme.clay,
                            in: RoundedRectangle(cornerRadius: 18))
            Text(category.displayTitle).font(.headline)
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TendTheme.secondary)
        }
        .padding(12).frame(minHeight: 72)
        .background(TendTheme.surface, in: RoundedRectangle(cornerRadius: 20))
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct PracticeCategoryListView: View {
    @Environment(AppStore.self) private var store
    let category: PracticeCategory

    private var practices: [Practice] {
        store.configuration.practices.filter { $0.category == category }
            .sorted { $0.durationSeconds == $1.durationSeconds ? $0.title < $1.title : $0.durationSeconds < $1.durationSeconds }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(practices) { practice in
                    PracticeListRow(practice: practice)
                    if practice.id != practices.last?.id { Divider().overlay(TendTheme.line) }
                }
            }
            .frame(maxWidth: 640).padding(24).frame(maxWidth: .infinity)
        }
        .tendScreen()
        .navigationTitle(category.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("practices.\(category.rawValue)")
    }
}

struct SavedView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let openToday: () -> Void

    private var savedPractices: [Practice] {
        store.data.savedPracticeIDs.compactMap { store.practice(id: $0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeading(title: "From your check-ins")
                    TimelineView(.periodic(from: .now, by: 60)) { _ in
                        let recommendations = store.savedRecommendations
                        if recommendations.isEmpty {
                            Text("No saved options yet")
                                .font(.subheadline).foregroundStyle(TendTheme.secondary)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(recommendations) { saved in
                                    SavedRecommendationCard(saved: saved)
                                }
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeading(title: "Saved practices")
                    if savedPractices.isEmpty {
                        Text("Nothing saved yet")
                            .font(.subheadline).foregroundStyle(TendTheme.secondary)
                        Button("Browse practices") { dismiss(); openToday() }
                            .buttonStyle(SecondaryButtonStyle())
                            .accessibilityIdentifier("saved.explore")
                    } else {
                        ForEach(PracticeCategory.allCases, id: \.self) { category in
                            let practices = savedPractices.filter { $0.category == category }
                            if !practices.isEmpty {
                                Text(category.displayTitle)
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.top, 8)
                                ForEach(practices) { PracticeListRow(practice: $0) }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 640).padding(24).frame(maxWidth: .infinity)
        }
        .tendScreen()
        .navigationTitle("Saved for later")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("saved.screen")
    }
}

private struct SavedRecommendationCard: View {
    @Environment(AppStore.self) private var store
    let saved: SavedRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Demo window · until \(saved.expiresAt.formatted(date: .omitted, time: .shortened))")
                .font(.subheadline).foregroundStyle(TendTheme.secondary)
            ForEach(store.remainingPractices(for: saved)) { practice in
                NavigationLink {
                    if saved.isAvailable(at: Date()) {
                        PracticeDetailView(practice: practice, checkInID: saved.checkInID)
                    } else {
                        ExpiredRecommendationView()
                    }
                } label: {
                    HStack(spacing: 12) {
                        PracticeSymbol(symbol: practice.symbol, size: 24, color: TendTheme.forest)
                            .frame(width: 40)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(practice.title).font(.body.weight(.semibold))
                            Text("\(max(1, practice.durationSeconds / 60)) min · \(practice.category.displayTitle)")
                                .font(.subheadline).foregroundStyle(TendTheme.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.subheadline)
                    }
                    .frame(minHeight: 56).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("saved.recommendation.\(practice.id)")
            }
            Button("Remove saved options", role: .destructive) {
                _ = store.removeSavedRecommendation(saved)
            }
            .font(.subheadline)
            .frame(minHeight: 44)
        }
        .tendCard()
    }
}

extension PracticeCategory {
    var displayTitle: String {
        switch self {
        case .movement: "Physical activity"
        case .mindfulness: "Mindfulness"
        }
    }
}
