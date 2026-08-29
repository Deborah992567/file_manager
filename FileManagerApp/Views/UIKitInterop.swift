import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PhotosUI
import QuickLook

// MARK: - Files app importer

/// `UIDocumentPickerViewController` bridge — the only sanctioned way to import
/// files from the Files app / iCloud Drive on iOS.
struct DocumentPickerView: UIViewControllerRepresentable {
    let completion: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.item, .folder],
            asCopy: true
        )
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        init(_ parent: DocumentPickerView) { self.parent = parent }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.completion(urls)
        }
    }
}

// MARK: - Photos importer

/// `PHPickerViewController` bridge — privacy-clean photo picking.
struct PhotoPickerView: UIViewControllerRepresentable {
    let completion: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 0
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPickerView
        init(_ parent: PhotoPickerView) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            var images: [UIImage] = []
            let group = DispatchGroup()
            for result in results {
                group.enter()
                let provider = result.itemProvider
                if provider.canLoadObject(ofClass: UIImage.self) {
                    provider.loadObject(ofClass: UIImage.self) { image, _ in
                        if let image = image as? UIImage { images.append(image) }
                        group.leave()
                    }
                } else {
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                self.parent.completion(images)
            }
        }
    }
}

// MARK: - Share sheet

/// Presents the share sheet for one or more files.
enum Share {
    @MainActor
    static func files(_ items: [FileItem]) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first?.rootViewController else { return }
        let urls = items.map(\.url)
        let vc = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = root.view
        root.present(vc, animated: true)
    }
}

// MARK: - Quick Look preview

/// `QLPreviewController` bridge for native preview of images/PDFs/videos/docs.
/// Reloads whenever the URL list changes so reopening re-renders correctly.
struct QuickLookView: UIViewControllerRepresentable {
    let urls: [URL]

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        uiViewController.reloadData()
    }

    func makeCoordinator() -> Coordinator { Coordinator(urls: urls) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let urls: [URL]
        init(urls: [URL]) { self.urls = urls }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { urls.count }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            PreviewItemSource(url: urls[index])
        }
    }
}

/// Minimal `QLPreviewItem` — QuickLook just needs a title + URL.
final class PreviewItemSource: NSObject, QLPreviewItem {
    let url: URL
    init(url: URL) { self.url = url; super.init() }
    var previewItemURL: URL? { url }
    var previewItemTitle: String? { url.lastPathComponent }
}