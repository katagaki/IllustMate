import Foundation

extension OriginalsManager {

    func deleteCloudOriginal(picID: String, in collectionID: String) async {
        guard isUbiquityAvailable(),
              let cloudURL = cloudURL(forPicID: picID, in: collectionID) else { return }
        await coordinatedDelete(at: cloudURL)
    }

    func deleteCloudOriginals(picIDs: [String], in collectionID: String) async {
        for id in picIDs {
            await deleteCloudOriginal(picID: id, in: collectionID)
        }
    }

    func deleteAllOriginals(in collectionID: String) async {
        guard isUbiquityAvailable(),
              let directory = libraryOriginalsDirectory(for: collectionID) else { return }
        await coordinatedDelete(at: directory)
    }
}
