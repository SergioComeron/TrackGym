//
//  FoodLog.swift
//  TrackGym
//
//  Updated to normalized nutrition models: Meal (aggregate) + FoodLog (entry)
//

import SwiftData
import Foundation

// Tipo de comida (controlado y localizable)
enum MealType: String, Codable, CaseIterable {
    case desayuno, mediaManana, comida, merienda, cena, postentreno, preentreno, intraentreno, otro
}

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

// Declaración global justo antes de FoodLog
internal let foodBySlug: [String: FoodSeed] = {
    Dictionary(uniqueKeysWithValues: defaultFoods.map { ($0.slug, $0) })
}()

/// Entrada de comida: una ración concreta de un `FoodItem`
/// Normaliza contra el catálogo para no duplicar macros/nombres.
@Model
final class FoodLog {
    var date: Date                 // cuándo se añadió/consumió
    var slug: String               // slug del alimento en el catálogo fijo
    var grams: Double              // cantidad en gramos
    var notes: String?

    // Marca cuándo se exportó esta entrada a HealthKit (nil = aún no exportada)
    var exportedToHealthKitAt: Date?

    // Relación con su Meal (opcional, permite añadir suelto y agrupar después)
    var meal: Meal?

    init(date: Date, slug: String, grams: Double, notes: String? = nil, meal: Meal? = nil) {
        self.date = date
        self.slug = slug
        self.grams = grams
        self.notes = notes
        self.meal = meal
    }

    // Lookup en catálogo fijo
    private var food: FoodSeed? { foodBySlug[slug] }
    private var factor: Double { grams / 100.0 }

    // Macros calculadas desde el catálogo (sin duplicar datos)
    var protein: Double { (food?.protein ?? 0) * factor }
    var carbs: Double   { (food?.carbs ?? 0) * factor }
    var fat: Double     { (food?.fat ?? 0) * factor }
    var kcal: Double { (food?.kcal ?? 0) * factor }


    // Removed fiber, sugars, sodiumMg as per instructions
    // var fiber: Double   { (food?.fiber ?? 0) * factor }
    // var sugars: Double  { (food?.sugars ?? 0) * factor }
    // var sodiumMg: Double { (food?.sodiumMg ?? 0) * factor }

    // Día normalizado (para listados diarios)
    var day: Date { date.startOfDay() }
}

// Utilidad de fecha (local)
extension Date {
    func startOfDay(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }
}
