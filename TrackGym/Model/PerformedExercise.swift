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
    @Relationship(inverse: \Entrenamiento.ejercicios)
    var entrenamiento: Entrenamiento?    // var series: [Serie] = []
    // <- lo añadiremos más tarde

    init(slug: String, entrenamiento: Entrenamiento? = nil) {
        self.slug = slug
        self.entrenamiento = entrenamiento
    }
}
