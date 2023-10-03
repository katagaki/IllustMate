//
//  IllustrationData.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/03.
//

import Foundation
import SwiftData

@Model
final class IllustrationData {
    var id = UUID().uuidString
    var data: Data = Data()
    @Relationship(deleteRule: .cascade,
                  inverse: \Illustration.illustrationData) var illustration: Illustration?

    init(id: String, data: Data) {
        self.id = id
        self.data = data
    }
}
