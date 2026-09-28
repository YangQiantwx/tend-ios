import SwiftUI

struct PracticeListRow: View {
    @Environment(AppStore.self) private var store
    let practice: Practice
    private var saved: Bool { store.data.savedPracticeIDs.contains(practice.id) }

    var body: some View {
        HStack(spacing: 8) {
            NavigationLink { PracticeDetailView(practice: practice) } label: {
                HStack(spacing: 16) {
                    PracticeSymbol(symbol: practice.symbol, size: 30,
                                   color: practice.category == .movement ? TendTheme.sea : TendTheme.terracotta)
                        .frame(width: 64, height: 64)
                        .background(practice.category == .movement ? TendTheme.sage : TendTheme.clay,
                                    in: RoundedRectangle(cornerRadius: 18))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(practice.title).font(.body.weight(.semibold))
                        Text("\(max(1, practice.durationSeconds / 60)) min")
                            .font(.subheadline).foregroundStyle(TendTheme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 12).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("practice.list.\(practice.id)")
            Button { _ = store.toggleSaved(practice) } label: {
                Image(systemName: saved ? "bookmark.fill" : "bookmark")
                    .font(.body).frame(width: 44, height: 48)
            }
            .tint(TendTheme.forest)
            .accessibilityLabel(saved ? "Unsave \(practice.title)" : "Save \(practice.title)")
            .accessibilityIdentifier("practice.save.\(practice.id)")
        }
    }
}
