import SwiftUI

struct ErrorView: View {
    let message: String
    var retry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.revError)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.revText)
                .multilineTextAlignment(.center)
            if let retry = retry {
                Button("Réessayer", action: retry)
                    .buttonStyle(.borderedProminent)
                    .tint(.revOrange)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
