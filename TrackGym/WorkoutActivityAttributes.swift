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
        
        /// Ejercicio actual en ejecución (opcional)
        var ejercicioActualID: UUID?
        var ejercicioActualNombre: String?

        /// Última serie añadida (opcional)
        var ultimaSerieNumero: Int?
        var ultimaSerieReps: Int?
        var ultimaSeriePeso: Double?
        var ultimaSerieDuracion: Int?

        init(startedAt: Date, endedAt: Date? = nil, progress: Double = 0.0, ejercicioActualID: UUID? = nil, ejercicioActualNombre: String? = nil, ultimaSerieNumero: Int? = nil, ultimaSerieReps: Int? = nil, ultimaSeriePeso: Double? = nil, ultimaSerieDuracion: Int? = nil) {
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.progress = progress
            self.ejercicioActualID = ejercicioActualID
            self.ejercicioActualNombre = ejercicioActualNombre
            self.ultimaSerieNumero = ultimaSerieNumero
            self.ultimaSerieReps = ultimaSerieReps
            self.ultimaSeriePeso = ultimaSeriePeso
            self.ultimaSerieDuracion = ultimaSerieDuracion
        }
    }

    /// Atributos fijos de la actividad
    var entrenamientoID: UUID
    var title: String
}

