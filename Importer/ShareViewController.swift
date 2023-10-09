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

class ShareViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    let modelContext = ModelContext({
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
    }())

    @IBOutlet weak var heroImage: UIImageView!

    @IBOutlet weak var introLabel: UILabel!
    @IBOutlet weak var albumsTable: UITableView!
    @IBOutlet weak var importButton: UIButton!

    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var bottomSpacer: UIView!

    var albums: [Album] = []
    var selectedAlbum: Album?

    var currentProgress: Int = 0
    var total: Int = 0
    var failedItemCount: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        // Configure UIKit stuff
        importButton.layer.cornerRadius = importButton.frame.height / 2
        importButton.layer.masksToBounds = true
        albumsTable.delegate = self
        albumsTable.dataSource = self

        // Load albums
        do {
            var fetchDescriptor = FetchDescriptor<Album>(sortBy: [SortDescriptor(\.name)])
            fetchDescriptor.propertiesToFetch = [\.name]
            albums = try modelContext.fetch(fetchDescriptor)
        } catch {
            debugPrint(error.localizedDescription)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        progressLabel.text = String(localized: "Importer.ProgressText")
    }

    @IBAction func startImport(_ sender: Any) {
        UIView.animate(withDuration: 0.25, delay: 0.0, options: [.preferredFramesPerSecond60]) { [self] in
            introLabel.layer.opacity = 0.0
            albumsTable.layer.opacity = 0.0
            importButton.layer.opacity = 0.0
        } completion: { [self] _ in
            introLabel.isHidden = true
            albumsTable.isHidden = true
            importButton.isHidden = true
            bottomSpacer.isHidden = false
            progressView.layer.opacity = 0.0
            progressLabel.layer.opacity = 0.0
            progressView.isHidden = false
            progressLabel.isHidden = false
            UIView.animate(withDuration: 0.25, delay: 0.0, options: [.preferredFramesPerSecond60]) { [self] in
                progressView.layer.opacity = 1.0
                progressLabel.layer.opacity = 1.0
            } completion: { [self] _ in
                importItems()
            }
        }
    }

    @IBAction func cancelImport(_ sender: Any) {
        extensionContext!.completeRequest(returningItems: nil, completionHandler: nil)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return albums.count + 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AlbumCell")!
        var configuration = UIListContentConfiguration.cell()
        switch indexPath.row {
        case 0:
            configuration.text = String(localized: "Importer.Album.None")
            if selectedAlbum == nil {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
        default:
            configuration.text = albums[indexPath.row - 1].name
            if let selectedAlbum, selectedAlbum.id == albums[indexPath.row - 1].id {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
        }
        cell.contentConfiguration = configuration
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
        case 0: selectedAlbum = nil
        default: selectedAlbum = albums[indexPath.row - 1]
        }
        tableView.reloadData()
    }

    func importItems() {
        // Clear memory used by albums array
        albums.removeAll()
        // Start import
        if let item = extensionContext?.inputItems.first as? NSExtensionItem {
            let attachments = item.attachments ?? []
            total = attachments.count
            Task {
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
                        importItem(loadedFile)
                    } else {
                        failedItemCount += 1
                    }
                    currentProgress += 1
                    progressView.progress = Float(currentProgress) / Float(total)
                }
                if failedItemCount == 0 {
                    progressLabel.text = String(localized: "Importer.DoneText")
                    heroImage.image = UIImage(systemName: "checkmark.circle.fill")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                        extensionContext!.completeRequest(returningItems: nil, completionHandler: nil)
                    }
                } else {
                    progressLabel.text = String(localized: "Importer.DoneText.WithError.\(failedItemCount)")
                    heroImage.image = UIImage(systemName: "exclamationmark.circle.fill")
                }
            }
        }
    }

    func loadItem(_ attachment: NSItemProvider, type: UTType) async -> Any? {
        return await withCheckedContinuation { continuation in
            attachment.loadItem(forTypeIdentifier: type.identifier, options: nil) { file, _ in
                continuation.resume(returning: (file))
            }
        }
    }

    func importItem(_ file: Any?, name: String = UUID().uuidString) {
        if let url = file as? URL, let imageData = try? Data(contentsOf: url),
            let image = UIImage(data: imageData) {
            importItem(image, name: url.lastPathComponent)
        } else if let image = file as? UIImage {
            if let pngData = image.pngData() {
                importIllustration(name, data: pngData)
            } else if let jpgData = image.jpegData(compressionQuality: 1.0) {
                importIllustration(name, data: jpgData)
            } else if let heicData = image.heicData() {
                importIllustration(name, data: heicData)
            }
        } else {
            failedItemCount += 1
        }
    }

    func importIllustration(_ name: String, data: Data) {
        let illustration = Illustration(name: name, data: data)
        if let selectedAlbum {
            illustration.containingAlbum = selectedAlbum
        }
        modelContext.insert(illustration)
    }
}
