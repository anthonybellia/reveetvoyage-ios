import Foundation
import UIKit

/// Multipart upload of avatar image to /api/auth/me/avatar.
/// Backend resizes + converts to WebP automatically.
final class AvatarUploadService {
    static let shared = AvatarUploadService()
    private let keychain = KeychainHelper.shared

    private init() {}

    func uploadAvatar(imageData: Data) async throws -> User {
        guard let token = keychain.getToken() else {
            throw NetworkError.unauthorized
        }
        guard let url = URL(string: APIConfig.baseURL.absoluteString + "/auth/me/avatar") else {
            throw NetworkError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let crlf = "\r\n"
        let mime = sniffMimeType(imageData) ?? "image/jpeg"
        let ext  = mime == "image/png" ? "png" : (mime == "image/webp" ? "webp" : "jpg")

        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"avatar\"; filename=\"avatar.\(ext)\"\(crlf)".data(using: .utf8)!)
        body.append("Content-Type: \(mime)\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(imageData)
        body.append("\(crlf)--\(boundary)--\(crlf)".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(NSError(domain: "InvalidResp", code: -1))
        }
        guard (200...299).contains(http.statusCode) else {
            throw NetworkError.serverError(statusCode: http.statusCode,
                                            message: String(data: data, encoding: .utf8))
        }

        struct AvatarResp: Decodable { let user: User }
        let decoded = try JSONDecoder().decode(AvatarResp.self, from: data)
        return decoded.user
    }

    /// Compress + resize on the device side first to keep the upload small.
    /// Returns JPEG data (backend converts to WebP anyway).
    static func prepareImageForUpload(_ image: UIImage, maxDimension: CGFloat = 1024) -> Data? {
        let resized = image.resized(toFit: maxDimension)
        return resized.jpegData(compressionQuality: 0.85)
    }

    private func sniffMimeType(_ data: Data) -> String? {
        guard data.count >= 4 else { return nil }
        let bytes = [UInt8](data.prefix(8))
        if bytes.starts(with: [0xFF, 0xD8]) { return "image/jpeg" }
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
        if data.count >= 12 {
            let chunk = data.subdata(in: 0..<12)
            if chunk.starts(with: "RIFF".data(using: .utf8)!) {
                if let s = String(data: chunk, encoding: .ascii), s.contains("WEBP") {
                    return "image/webp"
                }
            }
        }
        return nil
    }
}

private extension UIImage {
    func resized(toFit maxDimension: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return self }
        let ratio = maxDimension / maxSide
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
