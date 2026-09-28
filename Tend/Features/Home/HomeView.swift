import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 34
    @Binding var focusPractices: Bool
    @Binding var openSaved: Bool

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                GeometryReader { viewport in
                    ScrollView {
                        VStack(alignment: .leading, spacing: viewport.size.height < 650 ? 12 : 16) {
                            HStack(alignment: .center, spacing: 20) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("tend").font(.subheadline.weight(.semibold))
                                        .foregroundStyle(TendTheme.forest)
                                    Text("Today").font(TendTheme.display(titleSize))
                                        .accessibilityAddTraits(.isHeader)
                                }
                                Spacer(minLength: 0)
                                if !dynamicTypeSize.isAccessibilitySize {
                                    LandscapeView()
                                        .frame(width: 116, height: 74)
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                }
                            }
                            if store.data.settings.participantID == "UI-FIXTURE-ONLY" {
                                Label("Illustrative test data", systemImage: "flask")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(TendTheme.secondary)
                                    .accessibilityIdentifier("home.testData")
                            }
                            ReminderTimeline()
                            DailyCheckInCard()
                            NavigationLink {
                                SavedView { focusPractices = true }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "bookmark.fill")
                                        .foregroundStyle(TendTheme.forest)
                                        .frame(width: 36, height: 36)
                                        .background(TendTheme.sage, in: RoundedRectangle(cornerRadius: 10))
                                    Text("Saved for later").font(.body.weight(.semibold))
                                    Spacer()
                                    let count = store.data.savedPracticeIDs.count + store.savedRecommendations.count
                                    if count > 0 { Text("\(count)").foregroundStyle(TendTheme.secondary) }
                                    Image(systemName: "chevron.right").font(.subheadline)
                                }
                                .padding(16).frame(minHeight: 56)
                                .background(TendTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("today.saved")
                            PracticeDirectorySection().padding(.top, 4)
                                .id("practiceDirectory")
                            NavigationLink { LearningNoteView() } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: "book.closed")
                                        .font(.title2)
                                        .frame(width: 44, height: 44)
                                        .foregroundStyle(TendTheme.forest)
                                        .background(TendTheme.sage, in: RoundedRectangle(cornerRadius: 14))
                                    Text("Learn about stress").font(.body.weight(.semibold))
                                    Spacer(minLength: 4)
                                    Image(systemName: "chevron.right").font(.subheadline)
                                }
                                .padding(16)
                                .background(TendTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("today.learn")
                            .padding(.bottom, 24)
                        }.frame(maxWidth: 600).padding(.horizontal, 24).padding(.top, 8).frame(maxWidth: .infinity)
                    }
                    .tendScreen().toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(isPresented: $openSaved) {
                        SavedView { focusPractices = true }
                    }
                }
                .task(id: focusPractices) {
                    guard focusPractices else { return }
                    await Task.yield()
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo("practiceDirectory", anchor: .top)
                    }
                    focusPractices = false
                }
            }
        }
    }
}
