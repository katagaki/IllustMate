import Foundation
import Photos

struct PHAssetCollectionWrapper: Hashable {
    let collection: PHAssetCollection

    static func == (lhs: PHAssetCollectionWrapper, rhs: PHAssetCollectionWrapper) -> Bool {
        lhs.collection.localIdentifier == rhs.collection.localIdentifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(collection.localIdentifier)
    }
}
