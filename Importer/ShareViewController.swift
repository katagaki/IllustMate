//
//  ShareViewController.swift
//  Importer
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var progressLabel: UILabel!

    var currentProgress: Int = 0
    var total: Int = 0

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Album.self, Illustration.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema,
                                                    isStoredInMemoryOnly: false,
                                                    cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Get shared items
        let modelContext = ModelContext(sharedModelContainer)
        if let item = extensionContext?.inputItems.first as? NSExtensionItem {
            let attachments = (item.attachments ?? [])
                .filter({ $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) })
            total = attachments.count
            for attachment: NSItemProvider in attachments {
                attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { fileURL, _ in
                    if let fileURL = fileURL as? URL,
                       let imageData = try? Data(contentsOf: fileURL) {
                        let illustration = Illustration(name: fileURL.lastPathComponent, data: imageData)
                        modelContext.insert(illustration)
                    }
                    self.incrementProgress()
                    self.dismissIfCompleted()
                }
            }
        }
        // TODO: Await finish loading files
        // TODO: Show album picker
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        progressLabel.text = NSLocalizedString("Importer.ProgressText", comment: "")
    }

    func incrementProgress() {
        DispatchQueue.main.async { [self] in
            currentProgress += 1
            progressView.progress = Float(currentProgress) / Float(total)
        }
    }

    func dismissIfCompleted() {
        DispatchQueue.main.async { [self] in
            if currentProgress == total {
                extensionContext!.completeRequest(returningItems: nil, completionHandler: nil)
            }
        }
    }
}
