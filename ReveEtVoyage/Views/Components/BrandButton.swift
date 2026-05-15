import SwiftUI

struct BrandButton: View {
    let title: String
    var systemImage: String? = nil
    var isLoading: Bool = false
    var style: Style = .primary
    let action: () -> Void

    @State private var pressed = false

    enum Style {
        case primary, secondary, ghost, destructive
    }

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(foregroundColor)
                } else {
                    if let systemImage {
                        Image(systemName: systemImage)
                    }
                    Text(title)
                }
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(borderView)
            .shadow(color: shadowColor, radius: pressed ? 4 : 10, x: 0, y: pressed ? 2 : 6)
            .scaleEffect(pressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pressed)
        }
        .disabled(isLoading)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded   { _ in pressed = false }
        )
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .destructive: return .white
        case .secondary, .ghost: return .revBrown
        }
    }

    private var shadowColor: Color {
        switch style {
        case .primary: return Color.revOrange.opacity(0.35)
        case .destructive: return Color.revRed.opacity(0.35)
        case .secondary, .ghost: return .clear
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            LinearGradient(
                colors: [.revOrange, .revRed],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .destructive:
            Color.revRed
        case .secondary:
            Color.revYellow.opacity(0.25)
        case .ghost:
            Color.clear
        }
    }

    @ViewBuilder
    private var borderView: some View {
        if style == .ghost {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.revBrown.opacity(0.2), lineWidth: 1)
        }
    }
}
