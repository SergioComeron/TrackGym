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
    FoodSeed(slug: "atun_lata_natural", category: .protein, protein: 23.0, carbs: 0.0, fat: 1.0, kcal: 100),
    FoodSeed(slug: "atun_lata_aceite_oliva", category: .protein, protein: 23.0, carbs: 0.0, fat: 8.0, kcal: 160),
    FoodSeed(slug: "atun_lata_aceite_vegetal", category: .protein, protein: 23.0, carbs: 0.0, fat: 10.0, kcal: 180),
    // Lácteos altos en proteína (se miden tal cual)
    FoodSeed(slug: "queso_fresco_batido_0", category: .dairy, protein: 8.5, carbs: 3.8, fat: 0.2, kcal: 58),
    FoodSeed(slug: "yogur_griego_0", category: .dairy, protein: 10.0, carbs: 3.5, fat: 0.2, kcal: 59),
    FoodSeed(slug: "jamon_serrano", category: .protein, protein: 30.0, carbs: 0.0, fat: 12.0, kcal: 250),
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
    FoodSeed(slug: "pan_integral", category: .carb, protein: 9.0, carbs: 42.0, fat: 2.0, kcal: 252),
    FoodSeed(slug: "pan_normal", category: .carb, protein: 8.0, carbs: 49.0, fat: 3.0, kcal: 287),
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
    FoodSeed(slug: "naranja", category: .fruit, protein: 0.9, carbs: 12.0, fat: 0.2, kcal: 47),
    FoodSeed(slug: "arandanos", category: .fruit, protein: 0.7, carbs: 14.5, fat: 0.3, kcal: 57),
    FoodSeed(slug: "frambuesas", category: .fruit, protein: 1.2, carbs: 12.0, fat: 0.7, kcal: 52),
    FoodSeed(slug: "melocoton", category: .fruit, protein: 0.9, carbs: 10.0, fat: 0.3, kcal: 39),
    FoodSeed(slug: "kiwi", category: .fruit, protein: 1.1, carbs: 15.0, fat: 0.5, kcal: 61),
]

let supplementFoods: [FoodSeed] = [
    FoodSeed(slug: "proteina_whey", category: .misc, protein: 80.0, carbs: 7.0, fat: 6.0, kcal: 389),
    FoodSeed(slug: "proteina_iso", category: .misc, protein: 85.1, carbs: 2.0, fat: 1.0, kcal: 379),
    FoodSeed(slug: "amilopectina", category: .misc, protein: 0.0, carbs: 95.0, fat: 0.0, kcal: 380),
    FoodSeed(slug: "clusterdextrina", category: .misc, protein: 0.0, carbs: 95.0, fat: 0.0, kcal: 380),
    FoodSeed(slug: "creatina_monohidrato", category: .misc, protein: 0.0, carbs: 0.0, fat: 0.0, kcal: 0),
    FoodSeed(slug: "map_aminoacidos", category: .misc, protein: 100.0, carbs: 0.0, fat: 0.0, kcal: 400)
]

// Preparados / "fuera de dieta" (valores por 100 g)
let preparedFoods: [FoodSeed] = [
    // Bocadillo de calamares típico (aprox). Mezcla pan + calamar rebozado y frito.
    // Estimación por 100 g: ~11P / 33C / 11G / 275 kcal.
    FoodSeed(slug: "bocadillo_calamares", category: .misc, protein: 11.0, carbs: 33.0, fat: 11.0, kcal: 275),

    // Patatas fritas (ración completa, aprox 150 g -> valores por 100 g).
    // Estimación por 100 g: ~3P / 41C / 15G / 312 kcal.
    FoodSeed(slug: "patatas_fritas_racion", category: .misc, protein: 3.0, carbs: 41.0, fat: 15.0, kcal: 312),

    // Patatas fritas (media ración, aprox 75 g -> mismos valores por 100 g).
    FoodSeed(slug: "patatas_fritas_media", category: .misc, protein: 3.0, carbs: 41.0, fat: 15.0, kcal: 312),

    // VIPS Club Pollo (por 100 g, valores ajustados)
    // Referencia general club sandwich (~223 kcal/100 g): P 12.6 / C 19.9 / G 10.0
    FoodSeed(slug: "vips_club_pollo", category: .misc, protein: 12.6, carbs: 19.9, fat: 10.0, kcal: 223),

    // Burger King preparados (aprox valores por 100 g)
    FoodSeed(slug: "bk_whopper", category: .misc, protein: 13.0, carbs: 22.0, fat: 14.0, kcal: 260),
    FoodSeed(slug: "bk_crispy_chicken", category: .misc, protein: 12.0, carbs: 25.0, fat: 15.0, kcal: 280)
]

/// Tamaños de ración sugeridos (en gramos) para ciertos alimentos preparados.
/// Úsalo en la UI como atajo para no tener que introducir gramos manualmente.
/// Nota: un bocadillo de ~34 cm suele rondar ~350–400 g; fijamos 380 g por defecto.
let defaultServingGrams: [String: Double] = [
    "bocadillo_calamares": 380,
    "patatas_fritas_racion": 150,
    "patatas_fritas_media": 75,
    "vips_club_pollo": 320,
    "bk_whopper": 270,
    "bk_crispy_chicken": 200
]

let defaultServingGramsMcdonalds: [String: Double] = [
    "bigmac": 220,
    "mcroyal": 250,
    "cbo": 240,
    "mccrispy": 220,
    "nuggets_9": 160,
    "mcpollo": 210,
    "cuarto_libra_queso": 240,
    "mcextreme_bacon": 270,
    "mcwrap": 200,
    "cheeseburger": 115,
    "hamburguesa": 110,
    "patatas_pequenas": 80,
    "patatas_medianas": 110,
    "patatas_grandes": 150,
    "patatas_deluxe_pequenas": 85,
    "patatas_deluxe_medianas": 120,
    "patatas_deluxe_grandes": 160,
    "nuggets_6": 105,
    "nuggets_4": 70,
    "mcflurry": 170,
    "mini_mcflurry": 100,
    "sundae": 150,
    "apple_pie": 80,
    "cono_helado": 75
]

func defaultGrams(for slug: String) -> Double? {
    return defaultServingGrams[slug] ?? defaultServingGramsMcdonalds[slug]
}

let mcdonaldsFoods: [FoodSeed] = [
    FoodSeed(slug: "bigmac", category: .misc, protein: 25.0, carbs: 45.0, fat: 28.0, kcal: 550),
    FoodSeed(slug: "mcroyal", category: .misc, protein: 30.0, carbs: 40.0, fat: 30.0, kcal: 580),
    FoodSeed(slug: "cbo", category: .misc, protein: 27.0, carbs: 42.0, fat: 29.0, kcal: 570),
    FoodSeed(slug: "mccrispy", category: .misc, protein: 23.0, carbs: 40.0, fat: 25.0, kcal: 520),
    FoodSeed(slug: "nuggets_9", category: .misc, protein: 21.0, carbs: 18.0, fat: 30.0, kcal: 450),
    FoodSeed(slug: "mcpollo", category: .misc, protein: 27.0, carbs: 39.0, fat: 30.0, kcal: 570),
    FoodSeed(slug: "cuarto_libra_queso", category: .misc, protein: 28.0, carbs: 38.0, fat: 32.0, kcal: 600),
    FoodSeed(slug: "mcextreme_bacon", category: .misc, protein: 30.0, carbs: 40.0, fat: 35.0, kcal: 650),
    FoodSeed(slug: "mcwrap", category: .misc, protein: 20.0, carbs: 35.0, fat: 20.0, kcal: 430),
    FoodSeed(slug: "cheeseburger", category: .misc, protein: 15.0, carbs: 30.0, fat: 15.0, kcal: 300),
    FoodSeed(slug: "hamburguesa", category: .misc, protein: 14.0, carbs: 28.0, fat: 14.0, kcal: 290),
    FoodSeed(slug: "patatas_pequenas", category: .misc, protein: 3.0, carbs: 35.0, fat: 17.0, kcal: 350),
    FoodSeed(slug: "patatas_medianas", category: .misc, protein: 4.0, carbs: 40.0, fat: 20.0, kcal: 400),
    FoodSeed(slug: "patatas_grandes", category: .misc, protein: 5.0, carbs: 45.0, fat: 23.0, kcal: 450),
    FoodSeed(slug: "patatas_deluxe_pequenas", category: .misc, protein: 4.0, carbs: 30.0, fat: 22.0, kcal: 370),
    FoodSeed(slug: "patatas_deluxe_medianas", category: .misc, protein: 5.0, carbs: 35.0, fat: 25.0, kcal: 420),
    FoodSeed(slug: "patatas_deluxe_grandes", category: .misc, protein: 6.0, carbs: 40.0, fat: 28.0, kcal: 470),
    FoodSeed(slug: "nuggets_6", category: .misc, protein: 14.0, carbs: 12.0, fat: 20.0, kcal: 300),
    FoodSeed(slug: "nuggets_4", category: .misc, protein: 9.0, carbs: 8.0, fat: 13.0, kcal: 200),
    FoodSeed(slug: "mcflurry", category: .misc, protein: 8.0, carbs: 50.0, fat: 15.0, kcal: 350),
    FoodSeed(slug: "mini_mcflurry", category: .misc, protein: 4.0, carbs: 25.0, fat: 8.0, kcal: 180),
    FoodSeed(slug: "sundae", category: .misc, protein: 5.0, carbs: 35.0, fat: 10.0, kcal: 280),
    FoodSeed(slug: "apple_pie", category: .misc, protein: 2.0, carbs: 40.0, fat: 15.0, kcal: 300),
    FoodSeed(slug: "cono_helado", category: .misc, protein: 4.0, carbs: 30.0, fat: 10.0, kcal: 240)
]

let defaultFoods = proteinFoods + carbFoods + fatFoods + vegetableFoods + fruitFoods + supplementFoods + preparedFoods + mcdonaldsFoods
