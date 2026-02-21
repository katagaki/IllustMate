//
//  FileManager.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/04.
//

import Foundation

let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let orphansFolder = documentsURL.appendingPathComponent("Orphans")
let exportsFolder = documentsURL.appendingPathComponent("Export")

func createIfNotExists(_ url: URL?) {
    if let url, !directoryExistsAtPath(url) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    }
}

func directoryExistsAtPath(_ url: URL) -> Bool {
    var isDirectory: ObjCBool = true
    let exists = FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory)
    return exists && isDirectory.boolValue
}
