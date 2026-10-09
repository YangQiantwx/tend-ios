import SwiftUI

struct PracticeFeedbackView: View {
    let practice: Practice
    let draft: PracticeSession
    let allowPostDistress: Bool
    let onSaved: () -> Void
    @Environment(AppStore.self) private var store
    @State private var helpfulness: Int?
    @State private var postPracticeDistress: Int?
    @State private var note = ""
    @State private var didSave = false
    @State private var saveError: String?
    @FocusState private var noteFocused: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 34

    init(practice: Practice, draft: PracticeSession, allowPostDistress: Bool = false,
         onSaved: @escaping () -> Void) {
        self.practice = practice
        self.draft = draft
        self.allowPostDistress = allowPostDistress
        self.onSaved = onSaved
        _helpfulness = State(initialValue: draft.helpfulness)
        _postPracticeDistress = State(initialValue: draft.postPracticeDistress)
        _note = State(initialValue: draft.note ?? "")
    }

    private var showsPostDistress: Bool { allowPostDistress && draft.checkInID != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 10) {
                    if allowPostDistress {
                        Image(systemName: "checkmark")
                            .font(.system(size: 24, weight: .light)).foregroundStyle(TendTheme.forest)
                            .frame(width: 56, height: 56).background(TendTheme.sage, in: Circle())
                    }
                    Text(allowPostDistress ? "Practice complete" : "Your reflection")
                        .font(TendTheme.display(titleSize)).multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(practice.title)
                        .font(.subheadline).foregroundStyle(TendTheme.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 4)
                rating
                if showsPostDistress { distressRating }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add a note").font(.headline)
                    TextField("Optional", text: $note, axis: .vertical)
                        .lineLimit(2...4).padding(16)
                        .background(TendTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(TendTheme.line, lineWidth: 1))
                        .focused($noteFocused)
                        .accessibilityLabel("Optional practice note")
                        .accessibilityIdentifier("feedback.note")
                }
                Text("Feedback is optional.")
                    .font(.subheadline).foregroundStyle(TendTheme.secondary)
                if let saveError {
                    Label(saveError, systemImage: "exclamationmark.circle")
                        .font(.subheadline).foregroundStyle(TendTheme.terracotta)
                        .accessibilityIdentifier("feedback.error")
                }
            }.padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .task {
            if let saved = store.data.sessions.first(where: { $0.id == draft.id }) {
                helpfulness = saved.helpfulness
                postPracticeDistress = saved.postPracticeDistress
                note = saved.note ?? ""
            }
        }
        .navigationTitle(allowPostDistress ? "Practice complete" : "Edit reflection")
        .toolbar(allowPostDistress ? .hidden : .visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            Button(action: save) {
                Label("Done", systemImage: "checkmark")
            }
            .buttonStyle(PrimaryButtonStyle()).disabled(didSave)
            .accessibilityIdentifier("feedback.done")
            .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 8)
            .background(TendTheme.paper)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { noteFocused = false }
            }
        }
    }

    private var rating: some View {
        ratingScale(question: "How helpful was this practice?",
                    lower: "Not at all\nhelpful", upper: "Extremely\nhelpful",
                    selection: $helpfulness, identifier: "feedback.rating", name: "Helpfulness")
    }

    private var distressRating: some View {
        VStack(alignment: .leading, spacing: 16) {
            ratingScale(question: "How distressed do you feel right now?",
                        lower: "Not at all", upper: "Extremely",
                        selection: $postPracticeDistress, identifier: "feedback.postDistress",
                        name: "After-practice distress")
        }
    }

    private func ratingScale(question: String, lower: String, upper: String,
                             selection: Binding<Int?>, identifier: String, name: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(question).font(.title3.weight(.medium)).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        selection.wrappedValue = selection.wrappedValue == value ? nil : value
                    } label: {
                        Text("\(value)").font(.title3.weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(selection.wrappedValue == value ? TendTheme.onForest : TendTheme.ink)
                            .background(selection.wrappedValue == value ? TendTheme.forest : TendTheme.surface,
                                        in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(selection.wrappedValue == value ? TendTheme.forest : TendTheme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(name) \(value) of 5")
                    .accessibilityValue(selection.wrappedValue == value ? "Selected" : "Not selected")
                    .accessibilityAddTraits(selection.wrappedValue == value ? .isSelected : [])
                    .accessibilityIdentifier("\(identifier).\(value)")
                }
            }
            HStack(alignment: .top) {
                Text(lower)
                Spacer()
                Text(upper).multilineTextAlignment(.trailing)
            }.font(.subheadline).foregroundStyle(TendTheme.secondary)
        }
    }

    private func save() {
        guard !didSave else { return }
        noteFocused = false
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if store.updateSessionFeedback(sessionID: draft.id, helpfulness: helpfulness,
                                       note: trimmed.isEmpty ? nil : trimmed,
                                       postPracticeDistress: showsPostDistress ? postPracticeDistress : nil,
                                       allowPostDistress: showsPostDistress) {
            didSave = true
            onSaved()
        } else {
            saveError = "Couldn't save your reflection. Your answers are still here; please tap Done to try again."
        }
    }
}
