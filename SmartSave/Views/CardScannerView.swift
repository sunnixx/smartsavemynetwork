import SwiftUI
import VisionKit

struct CardScannerView: UIViewControllerRepresentable {
    let onResult: @Sendable (ParsedCard, UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onResult: @Sendable (ParsedCard, UIImage?) -> Void
        init(onResult: @escaping @Sendable (ParsedCard, UIImage?) -> Void) { self.onResult = onResult }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount > 0 else {
                onResult(ParsedCard(), nil)
                return
            }
            let image = scan.imageOfPage(at: 0)
            let callback = onResult
            CardScannerService.extractText(from: image) { lines in
                let parsed = CardTextParser.parse(lines)
                callback(parsed, image)
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onResult(ParsedCard(), nil)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onResult(ParsedCard(), nil)
        }
    }
}
