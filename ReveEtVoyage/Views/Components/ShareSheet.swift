import SwiftUI
import UIKit

/// SwiftUI wrapper around UIActivityViewController for sharing files,
/// URLs or text. Lift this into Components so any feature can reuse it.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
