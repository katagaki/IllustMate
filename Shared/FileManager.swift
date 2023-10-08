//
//  FileManager.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/04.
//

import Foundation

let appContainer = FileManager.default.url(forUbiquityContainerIdentifier: nil) ??
                   FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let documentsURL = appContainer.appendingPathComponent("Documents")
let illustrationsFolder = documentsURL.appendingPathComponent("Illustrations")
let thumbnailsFolder = documentsURL.appendingPathComponent("Thumbnails")
let importsFolder = documentsURL.appendingPathComponent("Imports")
let orphansFolder = documentsURL.appendingPathComponent("Orphans")
