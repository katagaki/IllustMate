import CoreTransferable
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct PicImageExportable: Codable, Transferable {

    var id: String
    var name: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .image) { exportable in
            guard let url = await PicOriginalExporter.imageFileURL(forPicID: exportable.id,
                                                                   name: exportable.name) else {
                throw PicExportError.unavailable
            }
            return SentTransferredFile(url)
        }
        .suggestedFileName { $0.name }
        ProxyRepresentation { (exportable: PicImageExportable) in
            PicTransferable(id: exportable.id)
        }
    }
}

struct PicVideoExportable: Codable, Transferable {

    var id: String
    var name: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .movie) { exportable in
            guard let url = await PicOriginalExporter.videoFileURL(forPicID: exportable.id,
                                                                   name: exportable.name) else {
                throw PicExportError.unavailable
            }
            return SentTransferredFile(url)
        }
        .suggestedFileName { $0.name }
        ProxyRepresentation { (exportable: PicVideoExportable) in
            PicTransferable(id: exportable.id)
        }
    }
}

enum PicExportError: Error {
    case unavailable
}

enum PicOriginalExporter {

    static func imageFileURL(forPicID id: String, name: String) async -> URL? {
        let collectionID = DataActor.shared.collectionID
        var data = await DataActor.shared.imageData(forPicWithID: id)
        if data == nil {
            data = await OriginalsManager.shared.fetchOriginal(picID: id, in: collectionID)
        }
        guard let data else { return nil }
        let url = temporaryURL(base: name, ext: imageFileExtension(for: data))
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    static func videoFileURL(forPicID id: String, name: String) async -> URL? {
        let collectionID = DataActor.shared.collectionID
        var sourceURL = await DataActor.shared.videoURL(forPicWithID: id)
        if sourceURL == nil {
            sourceURL = await OriginalsManager.shared.materializedVideoURL(picID: id, in: collectionID)
        }
        guard let sourceURL else { return nil }
        let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let url = temporaryURL(base: name, ext: ext)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: url)
            return url
        } catch {
            return nil
        }
    }

    private static func temporaryURL(base: String, ext: String) -> URL {
        let trimmed = (base as NSString).deletingPathExtension
        let stem = (trimmed.isEmpty ? base : trimmed)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(stem).\(ext)")
        try? FileManager.default.removeItem(at: url)
        return url
    }

    private static func imageFileExtension(for data: Data) -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let uti = CGImageSourceGetType(source),
              let type = UTType(uti as String),
              let ext = type.preferredFilenameExtension else {
            return "png"
        }
        return ext
    }
}
