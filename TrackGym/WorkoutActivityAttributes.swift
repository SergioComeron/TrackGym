//
//  WorkoutActivityAttributes.swift
//  TrackGym
//
//  Created by Sergio Comerón on 17/8/25.
//

import ActivityKit
import Foundation

struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Si quieres, puedes poner datos cambiantes aquí (no hace falta para un simple cronómetro)
        var startedAt: Date
        var endedAt: Date?
        var progress: Double
        
        init(startedAt: Date, endedAt: Date? = nil, progress: Double = 0.0) {
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.progress = progress
        }
    }

    /// Atributos fijos de la actividad
    var entrenamientoID: UUID
    var title: String
}
