import SwiftUI

struct GlassCard<Content: View>: View {
    let content: () -> Content
    var padding: CGFloat = 18
    var cornerRadius: CGFloat = 18

    init(padding: CGFloat = 18, cornerRadius: CGFloat = 18, @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.revCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.gray.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 4)
    }
}

struct AvatarView: View {
    let firstName: String
    let lastName: String
    var avatarPath: String? = nil
    var size: CGFloat = 44

    private var initials: String {
        let first = firstName.first.map { String($0) } ?? ""
        let last = lastName.first.map { String($0) } ?? ""
        return (first + last).uppercased()
    }

    private var avatarURL: URL? {
        guard let path = avatarPath, !path.isEmpty else { return nil }
        if path.hasPrefix("http") { return URL(string: path) }
        let base = APIConfig.baseURL.absoluteString.replacingOccurrences(of: "/api", with: "")
        return URL(string: base + path)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.revYellow, .revOrange, .revRed],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))

            if let url = avatarURL {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Text(initials)
                            .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
            } else {
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .shadow(color: Color.revOrange.opacity(0.3), radius: 6, x: 0, y: 3)
    }
}

struct SectionTitle: View {
    let title: String
    var systemImage: String? = nil
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.revOrange)
            }
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.revText)

            Spacer()

            if let trailing {
                Text(trailing)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.revTextSecondary)
            }
        }
    }
}
