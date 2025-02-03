//
//  Item.swift
//  wevebeenherebefore
//
//  Created by Nicholas Christowitz on 03.02.25.
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
