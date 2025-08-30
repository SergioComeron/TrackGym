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
    let kcal: Double    // por 100g

    var name: String { NSLocalizedString("\(slug)_name", comment: "") }
    var desc: String { NSLocalizedString("\(slug)_desc", comment: "") }
}

let proteinFoods: [FoodSeed] = [
    // Proteínas (crudo)
    FoodSeed(slug: "pollo_pechuga_cruda", category: .protein, protein: 22.5, carbs: 0.0, fat: 1.5, kcal: 104),
    FoodSeed(slug: "pavo_pechuga_cruda", category: .protein, protein: 23.0, carbs: 0.0, fat: 1.0, kcal: 102),
    FoodSeed(slug: "ternera_magra_5_cruda", category: .protein, protein: 21.0, carbs: 0.0, fat: 5.0, kcal: 134),
    FoodSeed(slug: "atun_fresco_crudo", category: .protein, protein: 23.0, carbs: 0.0, fat: 0.6, kcal: 102),
    FoodSeed(slug: "merluza_cruda", category: .protein, protein: 16.0, carbs: 0.0, fat: 0.9, kcal: 83),
    FoodSeed(slug: "salmon_crudo", category: .protein, protein: 20.0, carbs: 0.0, fat: 13.0, kcal: 217),
    FoodSeed(slug: "huevo_crudo", category: .protein, protein: 12.6, carbs: 1.1, fat: 10.6, kcal: 160),
    FoodSeed(slug: "clara_huevo", category: .protein, protein: 11.0, carbs: 0.7, fat: 0.2, kcal: 48),
    // Lácteos altos en proteína (se miden tal cual)
    FoodSeed(slug: "queso_fresco_batido_0", category: .dairy, protein: 8.5, carbs: 3.8, fat: 0.2, kcal: 58),
    FoodSeed(slug: "yogur_griego_0", category: .dairy, protein: 10.0, carbs: 3.5, fat: 0.2, kcal: 59)
]

let carbFoods: [FoodSeed] = [
    // Carbohidratos (crudo/seco)
    FoodSeed(slug: "arroz_blanco_crudo", category: .carb, protein: 7.0, carbs: 78.0, fat: 0.6, kcal: 361),
    FoodSeed(slug: "arroz_integral_crudo", category: .carb, protein: 7.5, carbs: 76.0, fat: 2.2, kcal: 365),
    FoodSeed(slug: "pasta_cruda", category: .carb, protein: 13.0, carbs: 75.0, fat: 1.5, kcal: 375),
    FoodSeed(slug: "avena_cruda", category: .carb, protein: 13.0, carbs: 67.0, fat: 7.0, kcal: 389),
    FoodSeed(slug: "harina_arroz", category: .carb, protein: 6.0, carbs: 80.0, fat: 0.7, kcal: 346),
    FoodSeed(slug: "harina_avena", category: .carb, protein: 13.0, carbs: 64.0, fat: 7.0, kcal: 381),
    FoodSeed(slug: "patata_cruda", category: .carb, protein: 2.0, carbs: 17.0, fat: 0.1, kcal: 77),
    FoodSeed(slug: "batata_cruda", category: .carb, protein: 1.6, carbs: 20.0, fat: 0.1, kcal: 85),
    // Pan y cereales listos para consumo (no aplica crudo)
    FoodSeed(slug: "pan_blanco", category: .carb, protein: 8.0, carbs: 49.0, fat: 3.0, kcal: 287),
    FoodSeed(slug: "tostas_centeno", category: .carb, protein: 11.0, carbs: 70.0, fat: 3.0, kcal: 361)
]

let fatFoods: [FoodSeed] = [
    // Grasas
    FoodSeed(slug: "aceite_oliva", category: .fat, protein: 0.0, carbs: 0.0, fat: 100.0, kcal: 900),
    FoodSeed(slug: "aguacate", category: .fat, protein: 2.0, carbs: 9.0, fat: 15.0, kcal: 177),
    FoodSeed(slug: "nueces", category: .fat, protein: 15.0, carbs: 14.0, fat: 65.0, kcal: 683),
    FoodSeed(slug: "almendras", category: .fat, protein: 21.0, carbs: 22.0, fat: 50.0, kcal: 642),
    FoodSeed(slug: "mantequilla_cacahuete", category: .fat, protein: 25.0, carbs: 20.0, fat: 50.0, kcal: 705),
    FoodSeed(slug: "aceitunas", category: .fat, protein: 1.0, carbs: 6.0, fat: 11.0, kcal: 115)
]

let vegetableFoods: [FoodSeed] = [
    FoodSeed(slug: "coliflor", category: .vegetable, protein: 1.9, carbs: 5.0, fat: 0.3, kcal: 25),
    FoodSeed(slug: "tomate_crudo", category: .vegetable, protein: 0.9, carbs: 3.9, fat: 0.2, kcal: 18),
    FoodSeed(slug: "judias_verdes", category: .vegetable, protein: 1.8, carbs: 7.0, fat: 0.2, kcal: 31)
]

let fruitFoods: [FoodSeed] = [
    FoodSeed(slug: "platano", category: .fruit, protein: 1.2, carbs: 23.0, fat: 0.3, kcal: 96),
    FoodSeed(slug: "sandia", category: .fruit, protein: 0.6, carbs: 8.0, fat: 0.2, kcal: 30),
    FoodSeed(slug: "melon", category: .fruit, protein: 0.8, carbs: 8.0, fat: 0.2, kcal: 34),
    FoodSeed(slug: "granada", category: .fruit, protein: 1.7, carbs: 19.0, fat: 1.2, kcal: 83),
    FoodSeed(slug: "manzana", category: .fruit, protein: 0.3, carbs: 14.0, fat: 0.2, kcal: 52),
    FoodSeed(slug: "naranja", category: .fruit, protein: 0.9, carbs: 12.0, fat: 0.2, kcal: 47)
]

let supplementFoods: [FoodSeed] = [
    FoodSeed(slug: "proteina_whey", category: .misc, protein: 80.0, carbs: 7.0, fat: 6.0, kcal: 389),
    FoodSeed(slug: "proteina_iso", category: .misc, protein: 85.1, carbs: 2.0, fat: 1.0, kcal: 379),
    FoodSeed(slug: "amilopectina", category: .misc, protein: 0.0, carbs: 95.0, fat: 0.0, kcal: 380),
    FoodSeed(slug: "clusterdextrina", category: .misc, protein: 0.0, carbs: 95.0, fat: 0.0, kcal: 380),
    FoodSeed(slug: "creatina_monohidrato", category: .misc, protein: 0.0, carbs: 0.0, fat: 0.0, kcal: 0),
    FoodSeed(slug: "map_aminoacidos", category: .misc, protein: 100.0, carbs: 0.0, fat: 0.0, kcal: 400)
]

let defaultFoods = proteinFoods + carbFoods + fatFoods + vegetableFoods + fruitFoods + supplementFoods
