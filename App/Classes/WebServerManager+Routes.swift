//
//  WebServerManager+Routes.swift
//  PicMate
//
//  Created by Claude on 2026/03/16.
//

import Foundation
import UIKit

extension WebServerManager {

    func handleRequest(_ request: HTTPRequest) async -> HTTPResponse {
        let path = request.path
        let components = path.split(separator: "/").map(String.init)

        if request.method == "GET" {
            if components.isEmpty {
                return serveMainPage()
            }
            if components == ["api", "albums"] {
                return await handleGetRootAlbums()
            }
            if components.count == 3 && components[0] == "api" && components[1] == "albums" {
                return await handleGetAlbum(id: components[2])
            }
            if components.count == 4 && components[0] == "api" && components[1] == "albums" && components[3] == "cover" {
                return await handleGetAlbumCover(id: components[2])
            }
            if components.count == 4 && components[0] == "api" && components[1] == "pics" && components[3] == "thumbnail" {
                return await handleGetPicThumbnail(id: components[2])
            }
            if components.count == 4 && components[0] == "api" && components[1] == "pics" && components[3] == "image" {
                return await handleGetPicImage(id: components[2])
            }
        }

        if request.method == "POST" {
            if components == ["api", "upload"] {
                return await handleUploadToRoot(request: request)
            }
            if components.count == 4 && components[0] == "api" && components[1] == "albums" && components[3] == "upload" {
                return await handleUploadToAlbum(id: components[2], request: request)
            }
        }

        return .notFound()
    }

    // MARK: - Album Routes

    private func handleGetRootAlbums() async -> HTTPResponse {
        do {
            let albums = try await DataActor.shared.albumsWithCounts(in: nil, sortedBy: .nameAscending)
            let pics = try await DataActor.shared.pics(in: nil, order: .reverse)
            let json: [String: Any] = [
                "name": "Collection",
                "albums": albums.map { Self.albumToJSON($0) },
                "pics": pics.map { Self.picToJSON($0) }
            ]
            let data = try JSONSerialization.data(withJSONObject: json)
            return .ok(json: data)
        } catch {
            return .internalError(error.localizedDescription)
        }
    }

    private func handleGetAlbum(id: String) async -> HTTPResponse {
        guard let album = await DataActor.shared.album(for: id) else {
            return .notFound()
        }
        do {
            let childAlbums = try await DataActor.shared.albumsWithCounts(in: album, sortedBy: .nameAscending)
            let pics = try await DataActor.shared.pics(in: album, order: .reverse)
            let json: [String: Any] = [
                "id": album.id,
                "name": album.name,
                "hasCover": album.coverPhoto != nil,
                "albums": childAlbums.map { Self.albumToJSON($0) },
                "pics": pics.map { Self.picToJSON($0) }
            ]
            let data = try JSONSerialization.data(withJSONObject: json)
            return .ok(json: data)
        } catch {
            return .internalError(error.localizedDescription)
        }
    }

    // MARK: - Image Routes

    private func handleGetAlbumCover(id: String) async -> HTTPResponse {
        guard let album = await DataActor.shared.album(for: id),
              let coverData = album.coverPhoto else {
            return .notFound()
        }
        return .ok(imageData: coverData, contentType: "image/jpeg")
    }

    private func handleGetPicThumbnail(id: String) async -> HTTPResponse {
        guard let data = await DataActor.shared.thumbnailData(forPicWithID: id) else {
            return .notFound()
        }
        return .ok(imageData: data, contentType: "image/jpeg")
    }

    private func handleGetPicImage(id: String) async -> HTTPResponse {
        guard let data = await DataActor.shared.imageData(forPicWithID: id) else {
            return .notFound()
        }
        let contentType = HTTPRequestParser.detectImageContentType(data)
        return .ok(imageData: data, contentType: contentType)
    }

    // MARK: - Upload Routes

    private func handleUploadToAlbum(id: String, request: HTTPRequest) async -> HTTPResponse {
        guard await DataActor.shared.album(for: id) != nil else {
            return .notFound()
        }
        return await processUpload(request: request, albumID: id)
    }

    private func handleUploadToRoot(request: HTTPRequest) async -> HTTPResponse {
        return await processUpload(request: request, albumID: nil)
    }

    private func processUpload(request: HTTPRequest, albumID: String?) async -> HTTPResponse {
        guard let contentType = request.headers["content-type"],
              contentType.contains("multipart/form-data"),
              let boundary = HTTPRequestParser.extractBoundary(from: contentType) else {
            return .badRequest("Expected multipart/form-data")
        }

        let files = HTTPRequestParser.parseMultipartFormData(body: request.body, boundary: boundary)
        guard !files.isEmpty else {
            return .badRequest("No files in upload")
        }

        var uploadedCount = 0
        for file in files {
            guard UIImage(data: file.data) != nil else { continue }
            let filename: String
            if file.filename.isEmpty {
                filename = Pic.newFilename()
            } else {
                let url = URL(fileURLWithPath: file.filename)
                filename = url.deletingPathExtension().lastPathComponent
            }
            await DataActor.shared.createPic(filename, data: file.data, inAlbumWithID: albumID)
            uploadedCount += 1
        }

        do {
            let json: [String: Any] = ["uploaded": uploadedCount]
            let data = try JSONSerialization.data(withJSONObject: json)
            return .ok(json: data)
        } catch {
            return .internalError(error.localizedDescription)
        }
    }

    // MARK: - HTML

    func serveMainPage() -> HTTPResponse {
        return .ok(html: Self.mainPageHTML)
    }

    // MARK: - JSON Helpers

    private static func albumToJSON(_ album: Album) -> [String: Any] {
        [
            "id": album.id,
            "name": album.name,
            "hasCover": album.coverPhoto != nil,
            "albumCount": album.albumCount(),
            "picCount": album.picCount()
        ]
    }

    private static func picToJSON(_ pic: Pic) -> [String: Any] {
        [
            "id": pic.id,
            "name": pic.name,
            "dateAdded": ISO8601DateFormatter().string(from: pic.dateAdded)
        ]
    }
}
