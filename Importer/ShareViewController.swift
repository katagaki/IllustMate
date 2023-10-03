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

    @IBOutlet weak var heroImage: UIImageView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var progressLabel: UILabel!

    var currentProgress: Int = 0
    var total: Int = 0

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Album.self, Illustration.self, IllustrationData.self
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
        // Configure navigation controller
        navigationController!.title = NSLocalizedString("Importer.Title", comment: "")
        // Get shared items
        let modelContext = ModelContext(sharedModelContainer)
        if let item = extensionContext?.inputItems.first as? NSExtensionItem {
            let attachments = (item.attachments ?? [])
                .filter({ $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) })
            total = attachments.count
            for attachment: NSItemProvider in attachments {
                attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { file, _ in
                    if let url = file as? URL,
                       let imageData = try? Data(contentsOf: url) {
                        let illustration = Illustration(name: url.lastPathComponent, data: imageData)
                        modelContext.insert(illustration)
                    } else if let image = file as? UIImage {
                        if let pngData = image.pngData() {
                            let illustration = Illustration(name: UUID().uuidString, data: pngData)
                            modelContext.insert(illustration)
                        } else if let jpgData = image.jpegData(compressionQuality: 1.0) {
                            let illustration = Illustration(name: UUID().uuidString, data: jpgData)
                            modelContext.insert(illustration)
                        }
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
                progressLabel.text = NSLocalizedString("Importer.DoneText", comment: "")
                heroImage.image = UIImage(systemName: "checkmark.circle.fill")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [self] in
                    extensionContext!.completeRequest(returningItems: nil, completionHandler: nil)
                }
            }
        }
    }
}
