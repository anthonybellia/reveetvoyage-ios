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
        static func etapes(voyageId: Int) -> String {
            "/voyages/\(voyageId)/etapes"
        }
        static func etape(voyageId: Int, etapeId: Int) -> String {
            "/voyages/\(voyageId)/etapes/\(etapeId)"
        }
        /// Upload / remplacement de l'image de couverture d'une étape (multipart).
        static func etapeCover(voyageId: Int, etapeId: Int) -> String {
            "/voyages/\(voyageId)/etapes/\(etapeId)/cover"
        }
        /// Ajout (POST multipart) ou suppression (DELETE) d'un billet d'étape.
        static func etapeTickets(voyageId: Int, etapeId: Int) -> String {
            "/voyages/\(voyageId)/etapes/\(etapeId)/tickets"
        }
        // Photon places autocomplete (public, under /api prefix)
        static let photon = "/photon"

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

        // Sign in with Apple / Google (mobile id_token exchange)
        static let appleLogin  = "/auth/apple/login"
        static let googleLogin = "/auth/google/login"

        // APNs device registration
        static let devices = "/devices"
        static func deviceByToken(_ token: String) -> String { "/devices/\(token)" }

        // Activity location ping (device GPS)
        static let activityLocation = "/activity/location"

        // Weather (Open-Meteo proxy with 15min cache)
        static let weather = "/weather"
    }

    static let requestTimeout: TimeInterval = 30
    static let resourceTimeout: TimeInterval = 60
}
