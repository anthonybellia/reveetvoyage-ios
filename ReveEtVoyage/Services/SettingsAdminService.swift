import Foundation

final class SettingsAdminService {
    static let shared = SettingsAdminService()
    private let apiClient = APIClient.shared
    private init() {}

    // MARK: - Settings

    func listSettings() async throws -> [AdminSetting] {
        let r: APIResponse<[AdminSetting]> = try await apiClient.get(
            path: "/admin/settings", requiresAuth: true)
        return r.data ?? []
    }

    func updateSettings(_ entries: [AdminSetting]) async throws {
        struct Body: Encodable { let entries: [AdminSetting] }
        let _: VoidResponse = try await apiClient.request(
            method: "PUT",
            path: "/admin/settings",
            body: Body(entries: entries),
            requiresAuth: true
        )
    }

    // MARK: - Email templates

    func listTemplates() async throws -> [AdminEmailTemplate] {
        let r: APIResponse<[AdminEmailTemplate]> = try await apiClient.get(
            path: "/admin/email-templates", requiresAuth: true)
        return r.data ?? []
    }

    func updateTemplate(id: Int, sujet: String?, contenu: String) async throws -> AdminEmailTemplate {
        struct Body: Encodable { let sujet: String?; let contenu: String }
        let r: APIResponse<AdminEmailTemplate> = try await apiClient.put(
            path: "/admin/email-templates/\(id)",
            body: Body(sujet: sujet, contenu: contenu),
            requiresAuth: true
        )
        guard let t = r.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Sauvegarde template échouée")
        }
        return t
    }

    func sendTestTemplate(id: Int, to email: String) async throws {
        struct Body: Encodable { let test_email: String }
        let _: VoidResponse = try await apiClient.request(
            method: "POST",
            path: "/admin/email-templates/\(id)/send-test",
            body: Body(test_email: email),
            requiresAuth: true
        )
    }
}
