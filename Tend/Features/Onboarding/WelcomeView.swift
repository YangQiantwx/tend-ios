import SwiftUI

struct WelcomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSettingUp = false
    @State private var name = ""
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 40

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Label("tend", systemImage: "leaf").font(TendTheme.display(36))
                    }
                    .padding(.top, 20)
                    LandscapeView().frame(height: max(170, min(230, geometry.size.height * 0.28)))
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 80, bottomLeadingRadius: 24, bottomTrailingRadius: 80, topTrailingRadius: 24))
                    VStack(alignment: .leading, spacing: 10) {
                        Text(isSettingUp ? "Your name" : "A moment for you")
                            .font(TendTheme.display(titleSize)).fixedSize(horizontal: false, vertical: true)
                        Text(isSettingUp ? "You can skip this." : "Check in, then choose movement or mindfulness.")
                            .font(.body).foregroundStyle(TendTheme.secondary)
                    }
                    if isSettingUp {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("First name (optional)", text: $name)
                                .textContentType(.givenName).autocorrectionDisabled()
                                .padding(16).background(TendTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                                .accessibilityIdentifier("onboarding.name")
                        }
                    }
                    Button(action: continueAction) {
                        HStack { Text(isSettingUp ? "Start my day" : "Let's begin"); Spacer(); Image(systemName: "arrow.right") }
                            .padding(.horizontal, 24)
                    }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("onboarding.continue")
                    Spacer(minLength: 24)
                }
                .frame(maxWidth: 540).padding(.horizontal, 28).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }.tendScreen()
    }

    private func continueAction() {
        if !isSettingUp {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { isSettingUp = true }
        } else {
            var settings = store.data.settings
            settings.displayName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
            settings.onboardingComplete = true
            _ = store.updateSettings(settings)
        }
    }
}
