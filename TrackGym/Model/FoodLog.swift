//
//  FoodLog.swift
//  TrackGym
//
//  Updated to normalized nutrition models: Meal (aggregate) + FoodLog (entry)
//

import SwiftData
import Foundation

/// Entrada de comida: una ración concreta de un `FoodItem`
/// Normaliza contra el catálogo para no duplicar macros/nombres.
@Model
final class FoodLog {
    @Attribute(.unique) var entryUUID: UUID
    var date: Date                 // cuándo se añadió/consumió
    var slug: String               // slug del alimento en el catálogo fijo
    var grams: Double              // cantidad en gramos
    var notes: String?

    // Marca cuándo se exportó esta entrada a HealthKit (nil = aún no exportada)
    var exportedToHealthKitAt: Date?
    /// Identificador único del objeto en HealthKit (si existe)
    var healthKitUUID: UUID?

    // Relación con su Meal (opcional, permite añadir suelto y agrupar después)
    var meal: Meal?

    init(date: Date, slug: String, grams: Double, notes: String? = nil, meal: Meal? = nil, healthKitUUID: UUID? = nil) {
        self.entryUUID = UUID()
        self.date = date
        self.slug = slug
        self.grams = grams
        self.notes = notes
        self.meal = meal
        self.healthKitUUID = healthKitUUID
    }

    // Lookup en catálogo fijo
    private var food: FoodSeed? { foodBySlug[slug] }
    private var factor: Double { grams / 100.0 }

    // Macros calculadas desde el catálogo (sin duplicar datos)
    var protein: Double { (food?.protein ?? 0) * factor }
    var carbs: Double   { (food?.carbs ?? 0) * factor }
    var fat: Double     { (food?.fat ?? 0) * factor }
    var kcal: Double { (food?.kcal ?? 0) * factor }

    // Día normalizado (para listados diarios)
    var day: Date { date.startOfDay() }
}

// Utilidad de fecha (local)
extension Date {
    func startOfDay(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }
}

// Tipo de comida (controlado y localizable)
enum MealType: String, Codable, CaseIterable {
    case desayuno, mediaManana, comida, merienda, cena, postentreno, preentreno, intraentreno, otro
}

// Declaración global justo antes de FoodLog
private let foodBySlug: [String: FoodSeed] = {
    Dictionary(uniqueKeysWithValues: defaultFoods.map { ($0.slug, $0) })
}()
