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
    }

    /// Atributos fijos de la actividad
    var entrenamientoID: UUID
    var title: String
}
