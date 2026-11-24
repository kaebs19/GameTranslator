//
//  Item.swift
//  GameTranslator
//
//  Created by Mohammed Saleh on 25/11/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
