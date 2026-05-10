import Foundation
import Security

final class KeychainHelper {
    static let shared = KeychainHelper()

    private let service = "be.reveetvoyage.app"

    private init() {}

    // MARK: - Token

    func saveToken(_ token: String) {
        save(value: token, account: "auth_token")
    }

    func getToken() -> String? {
        return readString(account: "auth_token")
    }

    func deleteToken() {
        delete(account: "auth_token")
    }

    // MARK: - User ID

    func saveUserId(_ userId: Int) {
        save(value: String(userId), account: "user_id")
    }

    func getUserId() -> Int? {
        guard let str = readString(account: "user_id") else { return nil }
        return Int(str)
    }

    func deleteUserId() {
        delete(account: "user_id")
    }

    // MARK: - Wipe all

    func clearAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Private helpers

    private func save(value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func readString(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
