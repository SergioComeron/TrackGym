//
//  FoodCatalog.swift
//  TrackGym
//
//  Created by Sergio Comerón on 26/8/25.
//
import Foundation

// MARK: - Catálogo de Alimentos

enum FoodCategory: String, Codable, Hashable {
    case protein
    case carb
    case fat
    case vegetable
    case fruit
    case dairy
    case beverage
    case misc
}

struct FoodSeed: Hashable {
    let slug: String
    let category: FoodCategory
    let protein: Double // por 100g
    let carbs: Double   // por 100g
    let fat: Double     // por 100g

    var name: String { NSLocalizedString("\(slug)_name", comment: "") }
    var desc: String { NSLocalizedString("\(slug)_desc", comment: "") }
}

let proteinFoods: [FoodSeed] = [
    // Proteínas (crudo)
    FoodSeed(slug: "pollo_pechuga_cruda", category: .protein, protein: 22.5, carbs: 0.0, fat: 1.5),
    FoodSeed(slug: "pavo_pechuga_cruda", category: .protein, protein: 23.0, carbs: 0.0, fat: 1.0),
    FoodSeed(slug: "ternera_magra_5_cruda", category: .protein, protein: 21.0, carbs: 0.0, fat: 5.0),
    FoodSeed(slug: "atun_fresco_crudo", category: .protein, protein: 23.0, carbs: 0.0, fat: 0.6),
    FoodSeed(slug: "merluza_cruda", category: .protein, protein: 16.0, carbs: 0.0, fat: 0.9),
    FoodSeed(slug: "salmon_crudo", category: .protein, protein: 20.0, carbs: 0.0, fat: 13.0),
    FoodSeed(slug: "huevo_crudo", category: .protein, protein: 12.6, carbs: 1.1, fat: 10.6),
    FoodSeed(slug: "clara_huevo", category: .protein, protein: 11.0, carbs: 0.7, fat: 0.2),
    // Lácteos altos en proteína (se miden tal cual)
    FoodSeed(slug: "queso_fresco_batido_0", category: .dairy, protein: 8.5, carbs: 3.8, fat: 0.2),
    FoodSeed(slug: "yogur_griego_0", category: .dairy, protein: 10.0, carbs: 3.5, fat: 0.2),
    // Suplementos
    FoodSeed(slug: "proteina_whey", category: .misc, protein: 80.0, carbs: 7.0, fat: 6.0),
    FoodSeed(slug: "proteina_iso", category: .misc, protein: 90.0, carbs: 2.0, fat: 1.0)
]

let carbFoods: [FoodSeed] = [
    // Carbohidratos (crudo/seco)
    FoodSeed(slug: "arroz_blanco_crudo", category: .carb, protein: 7.0, carbs: 78.0, fat: 0.6),
    FoodSeed(slug: "arroz_integral_crudo", category: .carb, protein: 7.5, carbs: 76.0, fat: 2.2),
    FoodSeed(slug: "pasta_cruda", category: .carb, protein: 13.0, carbs: 75.0, fat: 1.5),
    FoodSeed(slug: "avena_cruda", category: .carb, protein: 13.0, carbs: 67.0, fat: 7.0),
    FoodSeed(slug: "harina_arroz", category: .carb, protein: 6.0, carbs: 80.0, fat: 0.7),
    FoodSeed(slug: "harina_avena", category: .carb, protein: 13.0, carbs: 64.0, fat: 7.0),
    FoodSeed(slug: "patata_cruda", category: .carb, protein: 2.0, carbs: 17.0, fat: 0.1),
    FoodSeed(slug: "batata_cruda", category: .carb, protein: 1.6, carbs: 20.0, fat: 0.1),
    // Pan y cereales listos para consumo (no aplica crudo)
    FoodSeed(slug: "pan_blanco", category: .carb, protein: 8.0, carbs: 49.0, fat: 3.0),
    FoodSeed(slug: "tostas_centeno", category: .carb, protein: 11.0, carbs: 70.0, fat: 3.0)
]

let fatFoods: [FoodSeed] = [
    // Grasas
    FoodSeed(slug: "aceite_oliva", category: .fat, protein: 0.0, carbs: 0.0, fat: 100.0),
    FoodSeed(slug: "aguacate", category: .fat, protein: 2.0, carbs: 9.0, fat: 15.0),
    FoodSeed(slug: "nueces", category: .fat, protein: 15.0, carbs: 14.0, fat: 65.0),
    FoodSeed(slug: "almendras", category: .fat, protein: 21.0, carbs: 22.0, fat: 50.0),
    FoodSeed(slug: "mantequilla_cacahuete", category: .fat, protein: 25.0, carbs: 20.0, fat: 50.0)
]

let defaultFoods = proteinFoods + carbFoods + fatFoods
