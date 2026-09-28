import Foundation

extension AppStore {
    var supportRequests: [SupportRequest] {
        (data.supportRequests ?? []).sorted { $0.updatedAt > $1.updatedAt }
    }

    func saveSupportRequest(id: UUID?, destination: SupportDestination, subject: String,
                            message: String, status: SupportRequestStatus) -> SupportRequest? {
        let existing = id.flatMap { id in data.supportRequests?.first { $0.id == id } }
        do {
            let request = try SupportRequest.prepared(id: existing?.id ?? UUID(),
                destination: existing?.destination ?? destination, subject: subject, message: message,
                status: status, createdAt: existing?.createdAt)
            guard commit({ value in
                var requests = value.supportRequests ?? []
                requests.removeAll { $0.id == request.id }
                requests.append(request)
                value.supportRequests = requests
                value.events.append(event(status == .draft ? "support_draft_saved" : "support_request_saved_locally",
                    reference: request.id.uuidString,
                    details: ["destination": request.destination.rawValue, "delivery": "not_sent"]))
            }) else { return nil }
            return request
        } catch {
            persistenceError = error.localizedDescription
            return nil
        }
    }

    @discardableResult
    func connectFitbitDemo() -> Bool {
        guard data.fitbitDemoConnection?.isConnected != true else { return true }
        return commit { value in
            value.fitbitDemoConnection = FitbitDemoConnection(isConnected: true, connectedAt: Date())
            value.events.append(event("fitbit_demo_connected", details: ["source": "synthetic_demo"]))
        }
    }

    @discardableResult
    func syncFitbitDemo() -> Bool {
        guard var connection = data.fitbitDemoConnection, connection.isConnected else { return false }
        let now = Date()
        connection.lastSyncedAt = now
        return commit { value in
            let samples = FitbitDemoConnection.sampleDays(at: now)
            value.wearableDays.removeAll { $0.source == "synthetic_demo" }
            value.wearableDays.append(contentsOf: samples)
            value.fitbitDemoConnection = connection
            value.events.append(event("fitbit_demo_synced", details: ["source": "synthetic_demo", "days": "7"]))
        }
    }

    @discardableResult
    func disconnectFitbitDemo() -> Bool {
        guard var connection = data.fitbitDemoConnection, connection.isConnected else { return true }
        connection.isConnected = false
        return commit { value in
            value.fitbitDemoConnection = connection
            value.events.append(event("fitbit_demo_disconnected", details: ["source": "synthetic_demo"]))
        }
    }
}
