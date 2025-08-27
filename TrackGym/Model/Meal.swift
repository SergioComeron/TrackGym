//
//  Meal.swift
//  TrackGym
//
//  Created by Sergio Comerón on 27/8/25.
//
import SwiftData
import Foundation

@Model
final class Meal {
    var date: Date                 // fecha/hora real de la comida
    var type: MealType             // tipo de comida

    @Relationship(deleteRule: .cascade, inverse: \FoodLog.meal)
    var entries: [FoodLog] = []    // raciones que componen la comida

    init(date: Date, type: MealType) {
        self.date = date
        self.type = type
    }

    // Totales de la comida
    var totalProtein: Double { entries.reduce(0) { $0 + $1.protein } }
    var totalCarbs: Double   { entries.reduce(0) { $0 + $1.carbs } }
    var totalFat: Double     { entries.reduce(0) { $0 + $1.fat } }
    var totalKcal: Double    { entries.reduce(0) { $0 + $1.kcal } }

    // Día normalizado (útil para agrupar en la UI)
    var day: Date { date.startOfDay() }
}
