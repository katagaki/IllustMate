//
//  FileManager.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/04.
//

import Foundation

let isCloudSyncEnabled = FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil
let documentsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") ??
                   FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let illustrationsFolder = documentsURL.appendingPathComponent("Illustrations")
let orphansFolder = documentsURL.appendingPathComponent("Orphans")
