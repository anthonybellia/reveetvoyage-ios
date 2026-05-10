import SwiftUI
import UIKit

extension View {
    func revCard() -> some View {
        self
            .background(Color.revCardBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    func revSection() -> some View {
        self
            .padding()
            .revCard()
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}
