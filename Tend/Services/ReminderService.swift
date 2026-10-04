import Foundation
import UserNotifications

@MainActor
enum ReminderService {
    /// AppStore preference writes and OS scheduling share this gate, including rollback.
    private static var busy = false
    private static var waiters: [CheckedContinuation<Void, Never>] = []

    static func acquire() async {
        if !busy { busy = true; return }
        await withCheckedContinuation { waiters.append($0) }
    }
    static func release() {
        if waiters.isEmpty { busy = false } else { waiters.removeFirst().resume() }
    }

    @discardableResult
    static func replace(with plan: [PlannedReminder]) async throws -> [UNNotificationRequest] {
        let previous = await pending()
        let requests = plan.map(request)
        guard Set(previous.map(\.identifier)) != Set(requests.map(\.identifier)) else { return previous }
        do { try await restore(requests) }
        catch {
            let schedulingError = error
            do { try await restore(previous) }
            catch { throw ReminderError.failed("Scheduling failed, and the previous reminders could not be fully restored. \(error.localizedDescription)") }
            throw schedulingError
        }
        return previous
    }

    static func restore(_ requests: [UNNotificationRequest]) async throws {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: await pending().map(\.identifier))
        var failure: Error?
        for request in requests {
            do { try await center.add(request) } catch { failure = error }
        }
        if let failure { throw failure }
    }

    private static func pending() async -> [UNNotificationRequest] {
        await UNUserNotificationCenter.current().pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix("tend.ema.") }
    }

    private static func request(_ item: PlannedReminder) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Time for a check-in"
        content.body = "Time for your quick check-in. How are you feeling right now?"
        content.sound = .default
        content.userInfo = ["slotID": item.slotID, "occurrenceDate": item.date.timeIntervalSince1970]
        content.threadIdentifier = "tend.ema"
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: item.timezoneID) ?? .current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: item.date)
        components.timeZone = calendar.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)
    }

    enum ReminderError: LocalizedError {
        case failed(String)
        var errorDescription: String? { if case .failed(let message) = self { message } else { nil } }
    }
}

/// One local reminder for the provisional one-hour saved-option window.
@MainActor
enum SavedRecommendationReminder {
    static func replace(with plan: [PlannedSavedReminder]) async throws {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix("tend.saved.") }
        let expected = Set(plan.map(\.id))
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { !expected.contains($0) })
        let existing = Set(pending.map(\.identifier))
        for item in plan where !existing.contains(item.id) {
            let content = UNMutableNotificationContent()
            content.title = "Saved practices"
            content.body = "Your saved check-in options are still available. Open Today → Saved for later."
            content.sound = .default
            content.threadIdentifier = "tend.saved"
            content.userInfo = ["savedID": item.savedID.uuidString, "checkInID": item.checkInID.uuidString]
            let request = UNNotificationRequest(identifier: item.id, content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, item.date.timeIntervalSinceNow), repeats: false))
            try await center.add(request)
        }
    }

    static func cancel(_ id: UUID) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["tend.saved.\(id.uuidString)"])
    }

    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let ids = await center.pendingNotificationRequests().map(\.identifier)
            .filter { $0.hasPrefix("tend.saved.") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}

extension AppStore {
    /// Foreground refresh replenishes a maximum of 20 days, never past studyEndDate.
    func refreshNotificationStatus() async {
        guard dataMode.allowsSystemNotifications else {
            notificationsStatus = "System reminders are off in demo and test mode"
            return
        }
        await ReminderService.acquire()
        defer { ReminderService.release() }
        do {
            let authorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            let plan = try reminderPlan(enabled: data.settings.notificationsEnabled && authorization.allowsReminders)
            try await ReminderService.replace(with: plan)
            try await SavedRecommendationReminder.replace(with: savedReminderPlan(
                enabled: data.settings.notificationsEnabled && authorization.allowsReminders))
            setNotificationLabel(authorization: authorization, plan: plan)
        } catch { notificationsStatus = "Reminders need attention"; persistenceError = error.localizedDescription }
    }

    func setNotificationsEnabled(_ enabled: Bool) async {
        guard dataMode.allowsSystemNotifications else {
            notificationsStatus = "System reminders are off in demo and test mode"
            return
        }
        await ReminderService.acquire()
        defer { ReminderService.release() }
        do {
            let effectiveEnabled = enabled && isStudyActive
            if effectiveEnabled {
                let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                guard allowed else {
                    notificationsStatus = "Disabled in iOS Settings"
                    return
                }
            }
            let plan = try reminderPlan(enabled: effectiveEnabled)
            let previous = try await ReminderService.replace(with: plan)
            var settings = data.settings
            settings.notificationsEnabled = effectiveEnabled
            guard updateSettings(settings) else { try await ReminderService.restore(previous); return }
            try await SavedRecommendationReminder.replace(with: savedReminderPlan(enabled: effectiveEnabled))
            let authorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            setNotificationLabel(authorization: authorization, plan: plan)
        } catch { persistenceError = "Reminders could not be updated. \(error.localizedDescription)" }
    }

    func updateReminders(_ reminders: [ReminderSlot]) async -> Bool {
        if !dataMode.allowsSystemNotifications {
            do { try StudyConfiguration.validatePrompts(reminders) }
            catch { persistenceError = error.localizedDescription; return false }
            var settings = data.settings
            settings.reminders = reminders
            return updateSettings(settings)
        }
        await ReminderService.acquire()
        defer { ReminderService.release() }
        do {
            try StudyConfiguration.validatePrompts(reminders)
            let authorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            let plan = try reminderPlan(enabled: data.settings.notificationsEnabled && authorization.allowsReminders, slots: reminders)
            let previous = try await ReminderService.replace(with: plan)
            var settings = data.settings
            settings.reminders = reminders
            guard updateSettings(settings) else { try await ReminderService.restore(previous); return false }
            setNotificationLabel(authorization: authorization, plan: plan)
            return true
        } catch { persistenceError = "Your reminder times could not be updated. \(error.localizedDescription)"; return false }
    }

    private func savedReminderPlan(enabled: Bool) -> [PlannedSavedReminder] {
        guard enabled, isStudyActive else { return [] }
        return SavedReminderPlan.make(saved: data.savedRecommendations ?? [], sessions: data.sessions,
                                      studyEndDate: studyEndDate)
    }

    private func reminderPlan(enabled: Bool, slots: [ReminderSlot]? = nil) throws -> [PlannedReminder] {
        guard enabled, data.settings.onboardingComplete, isStudyActive else { return [] }
        return try ReminderPlan.make(slots: slots ?? data.settings.reminders,
                                     enrolledAt: data.settings.enrolledAt, studyEndDate: studyEndDate,
                                     completedTodaySlotIDs: completedSlotIDs)
    }

    private func setNotificationLabel(authorization: UNAuthorizationStatus, plan: [PlannedReminder]) {
        guard isStudyActive else { notificationsStatus = "Study complete · reminders paused"; return }
        guard authorization.allowsReminders else {
            notificationsStatus = authorization == .denied ? "Disabled in iOS Settings" : "Not enabled"
            return
        }
        guard data.settings.notificationsEnabled else { notificationsStatus = "Reminders paused"; return }
        guard let last = plan.last else { notificationsStatus = "No more reminders this study"; return }
        let calendar = Calendar.current
        let days = (calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()),
                                            to: calendar.startOfDay(for: last.date)).day ?? 0) + 1
        notificationsStatus = "3 daily reminders · next \(days) \(days == 1 ? "day" : "days")"
    }
}

private extension UNAuthorizationStatus {
    var allowsReminders: Bool {
        #if os(iOS)
        self == .authorized || self == .provisional || self == .ephemeral
        #else
        self == .authorized || self == .provisional
        #endif
    }
}

/// The latest tapped reminder survives view creation, onboarding and process restart.
@MainActor
enum NotificationInbox {
    private static let key = "tend.pending-reminder-route.v1"
    private static let savedKey = "tend.open-saved.v1"
    static var pending: ReminderRoute? {
        guard AppDataMode.current.allowsSystemNotifications else { return nil }
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ReminderRoute.self, from: data)
    }
    static func enqueue(_ route: ReminderRoute) {
        guard let data = try? JSONEncoder().encode(route) else { return }
        UserDefaults.standard.set(data, forKey: key)
        NotificationCenter.default.post(name: .tendReminderOpened, object: nil)
    }
    static func acknowledge(_ id: UUID) {
        if pending?.id == id { UserDefaults.standard.removeObject(forKey: key) }
    }
    static var shouldOpenSaved: Bool {
        AppDataMode.current.allowsSystemNotifications && UserDefaults.standard.bool(forKey: savedKey)
    }
    static func enqueueSaved() {
        UserDefaults.standard.set(true, forKey: savedKey)
        NotificationCenter.default.post(name: .tendSavedReminderOpened, object: nil)
    }
    static func acknowledgeSaved() { UserDefaults.standard.removeObject(forKey: savedKey) }
}

final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = NotificationRouter()
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let identifier = response.notification.request.identifier
        if identifier.hasPrefix("tend.saved.") {
            await NotificationInbox.enqueueSaved()
            return
        }
        guard identifier.hasPrefix("tend.ema.") else { return }
        let info = response.notification.request.content.userInfo
        let occurrence = (info["occurrenceDate"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
        let route = ReminderRoute(slotID: info["slotID"] as? String, occurrenceDate: occurrence)
        await NotificationInbox.enqueue(route)
    }
}

extension Notification.Name {
    static let tendReminderOpened = Notification.Name("tendReminderOpened")
    static let tendSavedReminderOpened = Notification.Name("tendSavedReminderOpened")
}
