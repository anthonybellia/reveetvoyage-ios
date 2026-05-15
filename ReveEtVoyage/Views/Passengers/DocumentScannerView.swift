import SwiftUI
import VisionKit

/// Wraps DataScannerViewController (iOS 16+) for live OCR text capture.
/// Returns the recognized full text once the user confirms.
struct DocumentScannerView: UIViewControllerRepresentable {
    var onScanned: (String) -> Void
    var onCancel: () -> Void

    static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> UIViewController {
        guard Self.isSupported else {
            return UnsupportedScannerVC(onCancel: onCancel)
        }

        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        context.coordinator.scanner = scanner

        // Start scanning when ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            try? scanner.startScanning()
        }
        return scanner
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanned: onScanned, onCancel: onCancel)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onScanned: (String) -> Void
        var onCancel: () -> Void
        weak var scanner: DataScannerViewController?
        private var captureWorkItem: DispatchWorkItem?

        init(onScanned: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.onScanned = onScanned
            self.onCancel = onCancel
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            scheduleCapture(items: allItems, scanner: dataScanner)
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didUpdate updatedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            scheduleCapture(items: allItems, scanner: dataScanner)
        }

        /// Auto-capture if we see at least 2 long uppercase lines (likely MRZ).
        private func scheduleCapture(items: [RecognizedItem], scanner: DataScannerViewController) {
            captureWorkItem?.cancel()

            let texts = items.compactMap { item -> String? in
                if case .text(let t) = item { return t.transcript } else { return nil }
            }

            // Look for MRZ-like pattern (long lines with < and uppercase)
            let mrzCandidates = texts.filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces).uppercased().replacingOccurrences(of: " ", with: "")
                return trimmed.contains("<") && (trimmed.count >= 30)
            }

            if mrzCandidates.count >= 2 {
                let work = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    scanner.stopScanning()
                    self.onScanned(texts.joined(separator: "\n"))
                }
                captureWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
            }
        }
    }
}

private final class UnsupportedScannerVC: UIViewController {
    var onCancel: () -> Void
    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = "Scanner non supporté\nsur cet appareil"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.onCancel()
        }
    }
}
