//
//  FileManager.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/04.
//

import Foundation

let documentsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
let illustrationsFolder = documentsURL?.appendingPathComponent("Illustrations")
let thumbnailsFolder = documentsURL?.appendingPathComponent("Thumbnails")
let importsFolder = documentsURL?.appendingPathComponent("Imports")
