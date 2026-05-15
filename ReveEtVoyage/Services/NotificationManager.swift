import Foundation
import UserNotifications
import UIKit

/// Schedules local notifications for a voyage at fixed lead times before departure.
///
/// J-15, J-7, J-2 (10:00 each), and J-1 (10:00 morning recap + 18:00 airport time hint).
/// All scheduled per-voyage with a stable identifier prefix so we can cancel & re-add
/// when the user reloads the voyage detail.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    private let cal = Calendar(identifier: .gregorian)

    private init() {}

    // MARK: - Permission

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        case .denied:
            return false
        case .authorized, .provisional, .ephemeral:
            return true
        @unknown default:
            return false
        }
    }

    // MARK: - Public API

    /// Re-schedule all notifications for this voyage. Wipes any previous.
    func scheduleVoyage(_ voyage: Voyage) async {
        await cancelVoyage(voyage.id)

        guard let depart = voyage.date_depart?.toDate() else { return }

        if depart < Date() { return }

        let leadTimes: [(days: Int, hour: Int, key: String, title: String, bodyTemplate: String)] = [
            (15, 10, "j15", "✈️ Plus que 15 jours !",
             "Ton voyage à %DEST% se rapproche. C'est le moment de penser aux passeports et à la valise."),
            (7, 10, "j7", "🎒 J-7 avant le départ",
             "Une semaine avant %DEST%. Vérifie tes documents et boucle ton planning."),
            (2, 10, "j2", "📋 J-2, on se prépare",
             "Plus que 48h avant %DEST%. Pense à l'enregistrement en ligne et au check-in."),
            (1, 10, "j1morning", "🛫 Demain c'est le départ !",
             "Direction %DEST% demain. Vérifie une dernière fois les horaires de vol."),
            (1, 18, "j1airport", "🛂 Heure idéale à l'aéroport",
             "Sois à l'aéroport demain à %AIRPORT_TIME% (2h avant le décollage de %DEST%)."),
        ]

        for spec in leadTimes {
            guard let triggerDate = cal.date(byAdding: .day, value: -spec.days, to: depart) else { continue }
            var comps = cal.dateComponents([.year, .month, .day], from: triggerDate)
            comps.hour = spec.hour
            comps.minute = 0
            guard let fireDate = cal.date(from: comps), fireDate > Date() else { continue }

            let body = spec.bodyTemplate
                .replacingOccurrences(of: "%DEST%", with: voyage.destination)
                .replacingOccurrences(of: "%AIRPORT_TIME%", with: airportArrivalTime(forDeparture: depart) ?? "tôt")

            let content = UNMutableNotificationContent()
            content.title = spec.title
            content.body = body
            content.sound = .default
            content.userInfo = [
                "voyage_id": voyage.id,
                "kind": spec.key,
            ]
            content.categoryIdentifier = "VOYAGE_REMINDER"

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                repeats: false
            )
            let id = "voyage-\(voyage.id)-\(spec.key)"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            try? await center.add(request)
        }

        // 30-min-before reminders for each étape with date + heure
        for etape in voyage.etapes ?? [] {
            guard let fireDate = etapeFireDate(etape), fireDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Dans 30 min : \(etape.titre)"
            content.body = etapeNotifBody(etape)
            content.sound = .default
            content.userInfo = [
                "voyage_id": voyage.id,
                "etape_id": etape.id,
                "kind": "etape-30min",
            ]
            content.categoryIdentifier = "ETAPE_REMINDER"

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                repeats: false
            )
            let id = "voyage-\(voyage.id)-etape-\(etape.id)-30min"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    func cancelVoyage(_ voyageId: Int) async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("voyage-\(voyageId)-") }
        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func pendingForVoyage(_ voyageId: Int) async -> Int {
        let pending = await center.pendingNotificationRequests()
        return pending.filter { $0.identifier.hasPrefix("voyage-\(voyageId)-") }.count
    }

    // MARK: - Helpers

    private func etapeFireDate(_ etape: VoyageEtape) -> Date? {
        guard let dateStr = etape.date, let heure = etape.heure else { return nil }
        guard let baseDate = dateStr.toDate() else { return nil }

        let parts = heure.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }

        var comps = cal.dateComponents([.year, .month, .day], from: baseDate)
        comps.hour = parts[0]
        comps.minute = parts[1]

        guard let etapeDate = cal.date(from: comps) else { return nil }
        return cal.date(byAdding: .minute, value: -30, to: etapeDate)
    }

    private func etapeNotifBody(_ etape: VoyageEtape) -> String {
        var parts: [String] = []
        if let heure = etape.heure { parts.append("Prévu à \(heure)") }
        if let lieu = etape.lieu, !lieu.isEmpty { parts.append(lieu) }
        else if let desc = etape.description, !desc.isEmpty { parts.append(desc) }
        return parts.isEmpty ? "Prépare-toi pour la prochaine étape." : parts.joined(separator: " — ")
    }

    private func airportArrivalTime(forDeparture date: Date) -> String? {
        guard let arrival = cal.date(byAdding: .hour, value: -2, to: date) else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_BE")
        f.dateFormat = "HH'h'mm"
        return f.string(from: arrival)
    }
}
