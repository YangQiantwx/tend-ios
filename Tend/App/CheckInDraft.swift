import Foundation

struct CheckInPresentation: Identifiable {
    let id = UUID()
    let draft: CheckInDraft
}

struct CheckInRequest: Identifiable {
    let id = UUID()
    let origin: CheckInOrigin
    let slotID: String?
}
