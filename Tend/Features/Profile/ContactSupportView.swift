import SwiftUI

extension SupportDestination {
    var title: String { self == .studyTeam ? "Contact study team" : "Technical support" }
    var symbol: String { self == .studyTeam ? "person.2" : "wrench.and.screwdriver" }
}

struct ContactSupportView: View {
    @Environment(AppStore.self) private var store
    @State private var showingComposer = false
    let kind: SupportDestination

    private var requests: [SupportRequest] { store.supportRequests.filter { $0.destination == kind } }

    var body: some View {
        List {
            Section {
                Label("Messages on this device", systemImage: kind.symbol).font(.headline)
                Text("Write a question and save it here. Tend cannot send messages to the team. Use Share when you are ready to choose a recipient in another app.")
                    .foregroundStyle(TendTheme.secondary)
                Button("Write a message") { showingComposer = true }
                    .accessibilityIdentifier("support.compose")
            }
            Section("Your messages") {
                if requests.isEmpty {
                    Text("No saved messages").foregroundStyle(TendTheme.secondary)
                }
                ForEach(requests) { request in
                    NavigationLink {
                        SupportRequestDetailView(requestID: request.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(request.subject.isEmpty ? "General question" : request.subject).font(.headline)
                            Text(request.message).lineLimit(2).foregroundStyle(TendTheme.secondary)
                            Text(request.status == .draft ? "Draft · not sent" : "Saved on device · not sent")
                                .font(.caption).foregroundStyle(TendTheme.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .accessibilityIdentifier("support.request.\(request.id)")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .tendScreen().tint(TendTheme.forest)
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingComposer) { SupportComposerView(destination: kind) }
    }
}

private struct SupportRequestDetailView: View {
    @Environment(AppStore.self) private var store
    @State private var showingEditor = false
    let requestID: UUID

    private var request: SupportRequest? { store.supportRequests.first { $0.id == requestID } }

    var body: some View {
        List {
            if let request {
                Section {
                    Text(request.subject.isEmpty ? "General question" : request.subject).font(.title3.weight(.semibold))
                    Text(request.message)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("support.detail.message")
                }
                Section("Status") {
                    Text(request.status == .draft ? "Draft saved on this device" : "Request saved on this device")
                        .accessibilityIdentifier("support.detail.status")
                    Text("Not sent. The study team has not received this message through Tend.")
                        .foregroundStyle(TendTheme.secondary)
                    LabeledContent("Updated", value: request.updatedAt.formatted(date: .abbreviated, time: .shortened))
                }
                Section {
                    Button("Edit message") { showingEditor = true }
                        .accessibilityIdentifier("support.edit")
                    ShareLink(item: request.shareText) {
                        Label("Share message", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("support.share")
                } footer: {
                    Text("Choose the destination yourself in the share sheet. Tend does not record delivery or replies.")
                }
            }
        }
        .scrollContentBackground(.hidden).tendScreen().tint(TendTheme.forest)
        .navigationTitle("Message")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditor) {
            if let request { SupportComposerView(destination: request.destination, existing: request) }
        }
    }
}

private struct SupportComposerView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case subject, message }
    @State private var subject: String
    @State private var message: String
    @State private var showingDiscard = false
    @State private var saveError: String?
    let destination: SupportDestination
    let existing: SupportRequest?

    init(destination: SupportDestination, existing: SupportRequest? = nil) {
        self.destination = destination
        self.existing = existing
        _subject = State(initialValue: existing?.subject ?? "")
        _message = State(initialValue: existing?.message ?? "")
    }

    private var hasContent: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var hasChanges: Bool { subject != (existing?.subject ?? "") || message != (existing?.message ?? "") }

    var body: some View {
        NavigationStack {
            Form {
                Section("Subject") {
                    TextField("Optional subject", text: $subject)
                        .accessibilityIdentifier("support.subject")
                        .focused($focusedField, equals: .subject)
                        .onChange(of: subject) { _, value in subject = String(value.prefix(120)) }
                }
                Section("Message") {
                    TextEditor(text: $message)
                        .frame(minHeight: 160)
                        .focused($focusedField, equals: .message)
                        .accessibilityLabel("Your message")
                        .accessibilityIdentifier("support.message")
                        .onChange(of: message) { _, value in message = String(value.prefix(4000)) }
                    Text("\(message.count) / 4,000 characters")
                        .font(.caption).foregroundStyle(TendTheme.secondary)
                }
                if let saveError {
                    Section { Text(saveError).foregroundStyle(TendTheme.terracotta) }
                }
                Section {
                    Button("Save request on device") { save(.savedLocally) }
                        .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("support.saveRequest")
                    Button("Save draft") { save(.draft) }
                        .disabled(!hasContent)
                        .accessibilityIdentifier("support.saveDraft")
                } footer: {
                    Text("Saving keeps this message on your device. Nothing is sent automatically.")
                }
            }
            .scrollContentBackground(.hidden).tendScreen().tint(TendTheme.forest)
            .navigationTitle("Write a message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges && hasContent { showingDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if focusedField != nil {
                        Button("Done") { focusedField = nil }
                            .accessibilityIdentifier("support.dismissKeyboard")
                    }
                }
            }
            .interactiveDismissDisabled(hasChanges && hasContent)
            .confirmationDialog("Keep this message?", isPresented: $showingDiscard, titleVisibility: .visible) {
                Button("Save draft") { save(.draft) }
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) { }
            }
        }
    }

    private func save(_ status: SupportRequestStatus) {
        guard store.saveSupportRequest(id: existing?.id, destination: destination,
            subject: subject, message: message, status: status) != nil else {
            saveError = store.persistenceError ?? "Your message could not be saved. Please try again."
            return
        }
        dismiss()
    }
}
