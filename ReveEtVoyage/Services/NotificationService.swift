import Foundation

/// Service réseau des notifications serveur (cloche de la Home).
/// Suit le même pattern que les autres services : singleton + `APIClient`
/// partagé (auth Bearer + décodage de dates centralisés).
final class NotificationService {
    static let shared = NotificationService()
    private let apiClient = APIClient.shared

    private init() {}

    /// Récupère la liste des notifications + le compteur de non-lues.
    func fetch() async throws -> (items: [AppNotification], unreadCount: Int) {
        let response: NotificationsResponse = try await apiClient.get(
            path: APIConfig.Endpoints.notifications,
            requiresAuth: true
        )
        let unread = response.unread_count ?? response.data.filter { !$0.lu }.count
        return (response.data, unread)
    }

    /// Renvoie uniquement le compteur de non-lues (utilisé par le badge de la cloche).
    func unreadCount() async throws -> Int {
        try await fetch().unreadCount
    }

    /// Marque une notification précise comme lue.
    func markRead(id: Int) async throws {
        let _: InvitationActionResponse = try await apiClient.post(
            path: APIConfig.Endpoints.notificationRead(id: id),
            requiresAuth: true
        )
    }

    /// Marque toutes les notifications comme lues.
    func markAllRead() async throws {
        let _: InvitationActionResponse = try await apiClient.post(
            path: APIConfig.Endpoints.notificationsReadAll,
            requiresAuth: true
        )
    }
}
