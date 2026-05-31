import Foundation
import Photos

struct PHCollectionListWrapper: Hashable {
    let collectionList: PHCollectionList

    static func == (lhs: PHCollectionListWrapper, rhs: PHCollectionListWrapper) -> Bool {
        lhs.collectionList.localIdentifier == rhs.collectionList.localIdentifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(collectionList.localIdentifier)
    }
}
