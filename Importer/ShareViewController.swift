//
//  ShareViewController.swift
//  Importer
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Get shared items
        if let item = extensionContext?.inputItems.first as? NSExtensionItem {
            for attachment: NSItemProvider in item.attachments ?? [] where
            attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { fileURL, _ in
                    // Load images
                    if let fileURL = fileURL as? URL,
                       let image = UIImage(contentsOfFile: fileURL.path(percentEncoded: false)) {
                        debugPrint(image)
                    }
                }
            }
        }
        // TODO: Await finish loading files
        // TODO: Show album picker
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
}
