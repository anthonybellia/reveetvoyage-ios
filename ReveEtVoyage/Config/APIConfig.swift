import Foundation

enum APIConfig {
    static let baseURL = URL(string: "https://www.reveetvoyage.be/api")!

    enum Endpoints {
        // Auth
        static let login = "/auth/login"
        static let register = "/auth/register"
        static let logout = "/auth/logout"
        static let me = "/auth/me"
        static let forgotPassword = "/auth/forgot-password"
        static let resetPassword = "/auth/reset-password"

        // Offres (public)
        static let offres = "/offres"

        // Voyages (authenticated)
        static let voyages = "/voyages"
        static func toggleEtape(voyageId: Int, etapeId: Int) -> String {
            "/voyages/\(voyageId)/etapes/\(etapeId)/toggle"
        }

        // Devis (authenticated)
        static let devis = "/devis"

        // Passengers (authenticated)
        static let passengers = "/passengers"

        // Messages (authenticated)
        static let messages = "/messages"
        static let messagesUnread = "/messages/unread-count"
        static let files = "/files"

        // Settings
        static let updatePassword    = "/auth/me/password"
        static let updatePreferences = "/auth/me/preferences"
    }

    static let requestTimeout: TimeInterval = 30
    static let resourceTimeout: TimeInterval = 60
}
