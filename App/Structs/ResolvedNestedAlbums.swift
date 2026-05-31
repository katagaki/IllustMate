import Photos

struct ResolvedNestedAlbums {
    let ownPicsCollection: PHAssetCollection?
    let albums: [PHAssetCollection]
    let folders: [PHCollectionList]
}
