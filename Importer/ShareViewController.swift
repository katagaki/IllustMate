import SwiftUI
import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    let itemsManager = SharedItemsManager()

    override func viewDidLoad() {
        super.viewDidLoad()

        let shareView = UIHostingController(rootView: ShareView(itemsManager: itemsManager))
        addChild(shareView)
        view.addSubview(shareView.view)
        shareView.view.translatesAutoresizingMaskIntoConstraints = false
        shareView.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        shareView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        shareView.view.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        shareView.view.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        view.bringSubviewToFront(shareView.view)
        shareView.view.backgroundColor = .systemBackground

        NotificationCenter.default.addObserver(forName: NSNotification.Name("close"),
                                               object: nil, queue: nil) { [weak self] _ in
            DispatchQueue.main.async {
                self?.close()
            }
        }

        loadItems()
    }

    func loadItems() {
        if let item = extensionContext?.inputItems.first as? NSExtensionItem {
            let attachments = item.attachments ?? []
            Task {
                var loadedFiles: [Any] = []
                var failedItemCount: Int = 0
                for attachment: NSItemProvider in attachments {
                    var loadedFile: Any?
                    if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                        loadedFile = await loadItem(attachment, type: UTType.image)
                    } else if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                        loadedFile = await loadItem(attachment, type: UTType.url)
                    } else if attachment.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                        loadedFile = await loadItem(attachment, type: UTType.fileURL)
                    }
                    if let loadedFile {
                        loadedFiles.append(loadedFile)
                    } else {
                        failedItemCount += 1
                    }
                }
                await MainActor.run {
                    itemsManager.items = loadedFiles
                    itemsManager.failedItemCount = failedItemCount
                    itemsManager.isLoaded = true
                }
            }
        }
    }

    func close() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    func loadItem(_ attachment: NSItemProvider, type: UTType) async -> Any? {
        return await withCheckedContinuation { continuation in
            attachment.loadItem(forTypeIdentifier: type.identifier, options: nil) { @Sendable file, _ in
                nonisolated(unsafe) let result = file as Any?
                continuation.resume(returning: result)
            }
        }
    }
}

@Observable
class SharedItemsManager {
    var items: [Any] = []
    var failedItemCount: Int = 0
    var isLoaded: Bool = false
}
