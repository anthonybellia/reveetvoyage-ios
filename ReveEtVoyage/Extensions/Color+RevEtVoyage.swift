import SwiftUI
import UIKit

extension Color {
    // Brand palette — revBrown adapts to dark mode for text readability
    static let revBrown = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.96, green: 0.90, blue: 0.85, alpha: 1.0)
            : UIColor(red: 0.121, green: 0.063, blue: 0.031, alpha: 1.0)
    })
    static let revBrownDark = Color(red: 0.121, green: 0.063, blue: 0.031)
    static let revOrange = Color(red: 0.941, green: 0.616, blue: 0.420)  // #f09d6b
    static let revYellow = Color(red: 0.949, green: 0.776, blue: 0.114)  // #f2c61d
    static let revRed = Color(red: 0.894, green: 0.373, blue: 0.376)     // #e45f60

    // Semantic colors (auto-adapt to dark mode via UIColor)
    static let revBackground = Color(UIColor.systemBackground)
    static let revCardBackground = Color(UIColor.secondarySystemBackground)
    static let revText = Color(UIColor.label)
    static let revTextSecondary = Color(UIColor.secondaryLabel)
    static let revError = Color.red
    static let revSuccess = Color.green
}
