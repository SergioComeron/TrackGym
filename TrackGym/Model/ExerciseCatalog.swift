//
//  ExerciseCatalog.swift
//  TrackGym
//
//  Created by Sergio Comerón on 19/8/25.
//

import Foundation

struct ExerciseSeed: Hashable {
    let slug: String
    let group: GrupoMuscular

    var name: String { NSLocalizedString("\(slug)_name", comment: "") }
    var desc: String { NSLocalizedString("\(slug)_desc", comment: "") }
}

// Catálogo inicial: ESPALDA
let backExercises: [ExerciseSeed] = [
    ExerciseSeed(slug: "dominadas_pronas", group: .espalda),
    ExerciseSeed(slug: "dominadas_supinas", group: .espalda),
    ExerciseSeed(slug: "pull_ups_neutras", group: .espalda),
    ExerciseSeed(slug: "jalon_agarre_abierto", group: .espalda),
    ExerciseSeed(slug: "jalon_maquina", group: .espalda),
    ExerciseSeed(slug: "jalon_agarre_cerrado", group: .espalda),
    ExerciseSeed(slug: "jalon_agarre_abierto_neutro", group: .espalda),
    ExerciseSeed(slug: "remo_barra", group: .espalda),
    ExerciseSeed(slug: "remo_en_punta", group: .espalda),
    ExerciseSeed(slug: "remo_mancuerna", group: .espalda),
    ExerciseSeed(slug: "remo_polea_baja", group: .espalda),
    ExerciseSeed(slug: "remo_gironda_agarre_cerrado", group: .espalda),
    ExerciseSeed(slug: "remo_gironda_barra_ancha", group: .espalda),
    ExerciseSeed(slug: "remo_gironda_prono_a_neutro", group: .espalda),
    ExerciseSeed(slug: "remo_gironda_barra_ancha_inclinado_adelante", group: .espalda),
    ExerciseSeed(slug: "remo_gironda_barra_agarre_neutro", group: .espalda),
    ExerciseSeed(slug: "remo_gironda_una_mano", group: .espalda),
    ExerciseSeed(slug: "lumbar_banco", group: .espalda),
    ExerciseSeed(slug: "pull_over_polea", group: .espalda),
]

// Hombro
let hombroExercises: [ExerciseSeed] = [
    ExerciseSeed(slug: "press_militar_barra", group: .hombro),
    ExerciseSeed(slug: "press_militar_mancuernas", group: .hombro),
    ExerciseSeed(slug: "press_militar_multipower", group: .hombro),
    ExerciseSeed(slug: "press_arnold", group: .hombro),
    ExerciseSeed(slug: "press_maquina", group: .hombro), // 🔹 nuevo
    ExerciseSeed(slug: "elevaciones_laterales_mancuernas", group: .hombro),
    ExerciseSeed(slug: "elevaciones_laterales_maquina", group: .hombro),
    ExerciseSeed(slug: "elevaciones_laterales_polea", group: .hombro),
    ExerciseSeed(slug: "elevaciones_frontales_mancuernas", group: .hombro),
    ExerciseSeed(slug: "elevaciones_frontales_barra", group: .hombro),
    ExerciseSeed(slug: "elevaciones_frontales_disco", group: .hombro), // 🔹 nuevo
    ExerciseSeed(slug: "pajaro_mancuernas", group: .hombro),
    ExerciseSeed(slug: "pajaro_maquina", group: .hombro),
    ExerciseSeed(slug: "remo_menton_barra", group: .hombro),
    ExerciseSeed(slug: "remo_menton_mancuernas", group: .hombro),
    ExerciseSeed(slug: "encogimientos_mancuernas", group: .hombro), // 🔹 nuevo
    ExerciseSeed(slug: "encogimientos_barra", group: .hombro)       // 🔹 opcional: otra variante

]

// Femoral
let femoralExercises: [ExerciseSeed] = [
    ExerciseSeed(slug: "curl_femoral_sentado", group: .femoral),
    ExerciseSeed(slug: "curl_femoral_tumbado", group: .femoral),
    ExerciseSeed(slug: "peso_muerto", group: .femoral),
    ExerciseSeed(slug: "peso_muerto_rumano", group: .femoral),
    ExerciseSeed(slug: "peso_muerto_rumano_mancuernas", group: .femoral),
    ExerciseSeed(slug: "peso_muerto_piernas_rigidas", group: .femoral),
    ExerciseSeed(slug: "peso_muerto_sumo", group: .femoral),
    ExerciseSeed(slug: "peso_muerto_sumo_mancuernas", group: .femoral)
]

// Aductor
let aductorExercises: [ExerciseSeed] = [
    ExerciseSeed(slug: "aductor_maquina", group: .aductor)
]

// Abductor
let abductorExercises: [ExerciseSeed] = [
    ExerciseSeed(slug: "abductor_maquina", group: .abductor)
]

// Glúteo
let gluteoExercises: [ExerciseSeed] = [
    ExerciseSeed(slug: "hip_thrust_maquina", group: .gluteo),
    ExerciseSeed(slug: "hip_thrust_barra", group: .gluteo),
    ExerciseSeed(slug: "patada_atras_maquina", group: .gluteo),
    ExerciseSeed(slug: "peso_muerto_sumohalterofilia", group: .gluteo),
    ExerciseSeed(slug: "puente_gluteo", group: .gluteo),
    ExerciseSeed(slug: "glute_kickback_polea", group: .gluteo)
]

// Abdomen
let abdomenExercises: [ExerciseSeed] = [
    ExerciseSeed(slug: "plancha", group: .abdomen),
    ExerciseSeed(slug: "elevacion_piernas_tumbado", group: .abdomen),
    ExerciseSeed(slug: "giros_rusos_disco", group: .abdomen),
    ExerciseSeed(slug: "crunch_abdominal", group: .abdomen),
    ExerciseSeed(slug: "crunch_maquina", group: .abdomen),
    ExerciseSeed(slug: "crunch_inverso", group: .abdomen),
    ExerciseSeed(slug: "ab_wheel", group: .abdomen)
]

// Tríceps
let tricepsExercises: [ExerciseSeed] = [
    ExerciseSeed(slug: "extension_triceps_cuerda_polea_alta", group: .triceps),
    ExerciseSeed(slug: "extension_triceps_barra_polea_alta", group: .triceps),
    ExerciseSeed(slug: "triceps_cuerda_tras_nuca", group: .triceps),
    ExerciseSeed(slug: "fondos_triceps_paralelas", group: .triceps),
    ExerciseSeed(slug: "fondos_triceps_maquina", group: .triceps),
    ExerciseSeed(slug: "fondos_triceps_banco", group: .triceps)
]

// Bíceps
let bicepsExercises: [ExerciseSeed] = [
    ExerciseSeed(slug: "curl_simultaneo_mancuernas", group: .biceps),
    ExerciseSeed(slug: "curl_martillo_alterno_mancuernas", group: .biceps),
    ExerciseSeed(slug: "curl_martillo_simultaneo_mancuernas", group: .biceps),
    ExerciseSeed(slug: "curl_martillo_polea_baja", group: .biceps),
    ExerciseSeed(slug: "curl_barra", group: .biceps),
    ExerciseSeed(slug: "curl_inclinado_alterno_mancuernas", group: .biceps),
    ExerciseSeed(slug: "curl_inclinado_simultaneo_mancuernas", group: .biceps),
    ExerciseSeed(slug: "curl_arana_barra", group: .biceps),
    ExerciseSeed(slug: "curl_arana_mancuernas", group: .biceps),
    ExerciseSeed(slug: "curl_concentrado", group: .biceps),
    ExerciseSeed(slug: "curl_banco_predicador_mancuernas", group: .biceps),
    ExerciseSeed(slug: "curl_banco_predicador_barra", group: .biceps)
]

// Si ya tienes defaultExercises:
let defaultExercises = backExercises
    + hombroExercises
    + femoralExercises
    + aductorExercises
    + abductorExercises
    + gluteoExercises
    + abdomenExercises
    + tricepsExercises
    + bicepsExercises
