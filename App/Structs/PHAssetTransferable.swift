//
//  PHAssetTransferable.swift
//  PicMate
//
//  Created on 2026/03/09.
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct PHAssetTransferable: Codable, Transferable {

    var localIdentifier: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: PHAssetTransferable.self, contentType: .phAsset)
    }
}

extension UTType {
    static var phAsset: UTType { UTType(exportedAs: "com.tsubuzaki.IllustMate.PHAsset") }
}
