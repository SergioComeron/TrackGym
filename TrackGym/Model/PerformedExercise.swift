//
//  PerformedExercise.swift
//  TrackGym
//
//  Created by Sergio Comerón on 19/8/25.
//

import SwiftData
import Foundation

@Model
final class PerformedExercise {
    // CloudKit: no unique constraints; provide default values for non-optional attributes
    var id: UUID = UUID()
    var slug: String = ""            // p.ej. "remo_barra" (se asigna en init)
    var createdAt: Date = Date()
    var order: Int = 0
    @Relationship(inverse: \Entrenamiento.ejercicios)
    var entrenamiento: Entrenamiento?

    @Relationship(deleteRule: .cascade)
    var sets: [ExerciseSet] = []

    init(slug: String, entrenamiento: Entrenamiento? = nil) {
        self.slug = slug
        self.entrenamiento = entrenamiento
    }
}
