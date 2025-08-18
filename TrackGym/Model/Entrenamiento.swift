//
//  Entrenamiento.swift
//  TrackGym
//
//  Created by Sergio Comerón on 17/8/25.
//

import SwiftData
import Foundation

@Model
final class Entrenamiento {
    var id: UUID?
    var startDate: Date?
    var endDate: Date?
    
    init(id: UUID = UUID(), startDate: Date? = Date(), endDate: Date? = nil) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
    }
}
