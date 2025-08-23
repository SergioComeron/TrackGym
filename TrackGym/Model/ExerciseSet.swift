//
//  ExerciseSet.swift
//  TrackGym
//
//  Created by Sergio Comerón on 19/8/25.
//

import SwiftData
import Foundation

@Model
final class ExerciseSet {
    var id: UUID = UUID()
    var reps: Int = 0
    var weight: Double = 0
    var order: Int = 0
    /// Duration of the exercise set in seconds
    var duration: Int = 0
    var createdAt: Date = Date()
    @Relationship(inverse: \PerformedExercise.sets)
    var performedExercise: PerformedExercise?

    init(reps: Int, weight: Double, order: Int = 0, duration: Int = 0, performedExercise: PerformedExercise? = nil, createdAt: Date = Date()) {
        self.reps = reps
        self.weight = weight
        self.order = order
        self.duration = duration
        self.performedExercise = performedExercise
        self.createdAt = createdAt
    }
}
