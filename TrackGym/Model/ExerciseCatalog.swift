//
//  ExerciseCatalog.swift
//  TrackGym
//
//  Created by Sergio Comerón on 19/8/25.
//

import Foundation

enum ExerciseType: String, Codable, Hashable {
    case reps
    case duration
}

struct ExerciseSeed: Hashable {
    let slug: String
    let group: GrupoMuscular
    let type: ExerciseType

    var name: String { NSLocalizedString("\(slug)_name", comment: "") }
    var desc: String { NSLocalizedString("\(slug)_desc", comment: "") }
}

// Catálogo inicial: ESPALDA
let backExercises: [ExerciseSeed] = [
    ExerciseSeed(slug: "dominadas_pronas", group: .espalda, type: .reps),
    ExerciseSeed(slug: "dominadas_supinas", group: .espalda, type: .reps),
    ExerciseSeed(slug: "pull_ups_neutras", group: .espalda, type: .reps),
    ExerciseSeed(slug: "jalon_agarre_abierto", group: .espalda, type: .reps),
    ExerciseSeed(slug: "jalon_maquina", group: .espalda, type: .reps),
    ExerciseSeed(slug: "jalon_agarre_cerrado", group: .espalda, type: .reps),
    ExerciseSeed(slug: "jalon_agarre_abierto_neutro", group: .espalda, type: .reps),
    ExerciseSeed(slug: "remo_barra", group: .espalda, type: .reps),
    ExerciseSeed(slug: "remo_en_punta", group: .espalda, type: .reps),
    ExerciseSeed(slug: "remo_mancuerna", group: .espalda, type: .reps),
    ExerciseSeed(slug: "remo_polea_baja", group: .espalda, type: .reps),
    ExerciseSeed(slug: "remo_gironda_agarre_cerrado", group: .espalda, type: .reps),
    ExerciseSeed(slug: "remo_gironda_barra_ancha", group: .espalda, type: .reps),
    ExerciseSeed(slug: "remo_gironda_prono_a_neutro", group: .espalda, type: .reps),
    ExerciseSeed(slug: "remo_gironda_barra_ancha_inclinado_adelante", group: .espalda, type: .reps),
    ExerciseSeed(slug: "remo_gironda_barra_agarre_neutro", group: .espalda, type: .reps),
    ExerciseSeed(slug: "remo_gironda_una_mano", group: .espalda, type: .reps),
    ExerciseSeed(slug: "lumbar_banco", group: .espalda, type: .reps),
    ExerciseSeed(slug: "pull_over_polea", group: .espalda, type: .reps),
    ExerciseSeed(slug: "pull_over_banco_mancuerna", group: .espalda, type: .reps),
]

// Hombro
let hombroExercises: [ExerciseSeed] = [
    ExerciseSeed(slug: "press_militar_barra", group: .hombro, type: .reps),
    ExerciseSeed(slug: "press_militar_mancuernas", group: .hombro, type: .reps),
    ExerciseSeed(slug: "press_militar_multipower", group: .hombro, type: .reps),
    ExerciseSeed(slug: "press_arnold", group: .hombro, type: .reps),
    ExerciseSeed(slug: "press_maquina", group: .hombro, type: .reps), // 🔹 nuevo
    ExerciseSeed(slug: "elevaciones_laterales_mancuernas", group: .hombro, type: .reps),
    ExerciseSeed(slug: "elevaciones_laterales_maquina", group: .hombro, type: .reps),
    ExerciseSeed(slug: "elevaciones_laterales_polea", group: .hombro, type: .reps),
    ExerciseSeed(slug: "elevaciones_frontales_mancuernas", group: .hombro, type: .reps),
    ExerciseSeed(slug: "elevaciones_frontales_barra", group: .hombro, type: .reps),
    ExerciseSeed(slug: "elevaciones_frontales_disco", group: .hombro, type: .reps), // 🔹 nuevo
    ExerciseSeed(slug: "pajaro_mancuernas", group: .hombro, type: .reps),
    ExerciseSeed(slug: "pajaro_maquina", group: .hombro, type: .reps),
    ExerciseSeed(slug: "remo_menton_barra", group: .hombro, type: .reps),
    ExerciseSeed(slug: "remo_menton_mancuernas", group: .hombro, type: .reps),
    ExerciseSeed(slug: "encogimientos_mancuernas", group: .hombro, type: .reps), // 🔹 nuevo
    ExerciseSeed(slug: "encogimientos_barra", group: .hombro, type: .reps),       // 🔹 opcional: otra variante
    ExerciseSeed(slug: "face_pull", group: .hombro, type: .reps)
]

// Pecho
let pechoExercises: [ExerciseSeed] = [
    ExerciseSeed(slug: "press_inclinado_mancuernas", group: .pecho, type: .reps),
    ExerciseSeed(slug: "press_inclinado_multipower", group: .pecho, type: .reps),
    ExerciseSeed(slug: "press_inclinado_barra", group: .pecho, type: .reps),
    ExerciseSeed(slug: "press_plano_mancuernas", group: .pecho, type: .reps),
    ExerciseSeed(slug: "press_plano_barra", group: .pecho, type: .reps),
    ExerciseSeed(slug: "press_plano_multipower", group: .pecho, type: .reps),
    ExerciseSeed(slug: "press_plano_maquina", group: .pecho, type: .reps),
    ExerciseSeed(slug: "press_inclinado_maquina", group: .pecho, type: .reps),
    ExerciseSeed(slug: "aperturas_banco_plano", group: .pecho, type: .reps),
    ExerciseSeed(slug: "aperturas_banco_inclinado", group: .pecho, type: .reps),
    ExerciseSeed(slug: "aperturas_peck_deck", group: .pecho, type: .reps),
    ExerciseSeed(slug: "aperturas_maquina_inclinado", group: .pecho, type: .reps), // inclined machine fly
    ExerciseSeed(slug: "contractora_maquina", group: .pecho, type: .reps),
    ExerciseSeed(slug: "cruces_polea_alta", group: .pecho, type: .reps),
    ExerciseSeed(slug: "cruces_polea_media", group: .pecho, type: .reps),
    ExerciseSeed(slug: "cruces_polea_baja", group: .pecho, type: .reps),
    ExerciseSeed(slug: "fondos_paralelas_pecho", group: .pecho, type: .reps),
    ExerciseSeed(slug: "fondos_maquina_pecho", group: .pecho, type: .reps),
    ExerciseSeed(slug: "cruces_maquina_pecho", group: .pecho, type: .reps), // machine high-to-low fly
    ExerciseSeed(slug: "pull_over_banco_mancuerna", group: .pecho, type: .reps)
]

// Femoral
let femoralExercises: [ExerciseSeed] = [
    ExerciseSeed(slug: "curl_femoral_sentado", group: .femoral, type: .reps),
    ExerciseSeed(slug: "curl_femoral_tumbado", group: .femoral, type: .reps),
    ExerciseSeed(slug: "peso_muerto", group: .femoral, type: .reps),
    ExerciseSeed(slug: "peso_muerto_rumano", group: .femoral, type: .reps),
    ExerciseSeed(slug: "peso_muerto_rumano_mancuernas", group: .femoral, type: .reps),
    ExerciseSeed(slug: "peso_muerto_piernas_rigidas", group: .femoral, type: .reps),
    ExerciseSeed(slug: "peso_muerto_sumo", group: .femoral, type: .reps),
    ExerciseSeed(slug: "peso_muerto_sumo_mancuernas", group: .femoral, type: .reps)
]

// Cuádriceps
let cuadricepsExercises: [ExerciseSeed] = [
    ExerciseSeed(slug: "prensa_inclinada", group: .cuadriceps, type: .reps),
    ExerciseSeed(slug: "prensa_horizontal", group: .cuadriceps, type: .reps),
    ExerciseSeed(slug: "sentadilla_hack", group: .cuadriceps, type: .reps),
    ExerciseSeed(slug: "sentadilla_multipower", group: .cuadriceps, type: .reps),
    ExerciseSeed(slug: "extension_cuadriceps", group: .cuadriceps, type: .reps),
    ExerciseSeed(slug: "sentadilla_sissy", group: .cuadriceps, type: .reps),
    ExerciseSeed(slug: "sentadilla_bulgara_multipower", group: .cuadriceps, type: .reps),
    ExerciseSeed(slug: "sentadilla_bulgara_mancuerna", group: .cuadriceps, type: .reps),
    ExerciseSeed(slug: "sentadilla_libre_barra", group: .cuadriceps, type: .reps),
    ExerciseSeed(slug: "sentadilla_frontal_barra", group: .cuadriceps, type: .reps),
    ExerciseSeed(slug: "zancadas_mancuernas", group: .cuadriceps, type: .reps),
    ExerciseSeed(slug: "zancadas_barra", group: .cuadriceps, type: .reps)
]

// Aductor
let aductorExercises: [ExerciseSeed] = [
    ExerciseSeed(slug: "aductor_maquina", group: .aductor, type: .reps)
]

// Abductor
let abductorExercises: [ExerciseSeed] = [
    ExerciseSeed(slug: "abductor_maquina", group: .abductor, type: .reps)
]

// Glúteo
let gluteoExercises: [ExerciseSeed] = [
    ExerciseSeed(slug: "hip_thrust_maquina", group: .gluteo, type: .reps),
    ExerciseSeed(slug: "hip_thrust_barra", group: .gluteo, type: .reps),
    ExerciseSeed(slug: "patada_atras_maquina", group: .gluteo, type: .reps),
    ExerciseSeed(slug: "peso_muerto_sumohalterofilia", group: .gluteo, type: .reps),
    ExerciseSeed(slug: "puente_gluteo", group: .gluteo, type: .reps),
    ExerciseSeed(slug: "glute_kickback_polea", group: .gluteo, type: .reps)
]

// Abdomen
let abdomenExercises: [ExerciseSeed] = [
    ExerciseSeed(slug: "plancha", group: .abdomen, type: .duration),
    ExerciseSeed(slug: "elevacion_piernas_tumbado", group: .abdomen, type: .reps),
    ExerciseSeed(slug: "giros_rusos_disco", group: .abdomen, type: .reps),
    ExerciseSeed(slug: "inclinaciones_laterales_disco", group: .abdomen, type: .reps),
    ExerciseSeed(slug: "crunch_abdominal", group: .abdomen, type: .reps),
    ExerciseSeed(slug: "crunch_maquina", group: .abdomen, type: .reps),
    ExerciseSeed(slug: "crunch_inverso", group: .abdomen, type: .reps),
    ExerciseSeed(slug: "ab_wheel", group: .abdomen, type: .reps)
]

// Tríceps
let tricepsExercises: [ExerciseSeed] = [
    ExerciseSeed(slug: "extension_triceps_cuerda_polea_alta", group: .triceps, type: .reps),
    ExerciseSeed(slug: "extension_triceps_barra_polea_alta", group: .triceps, type: .reps),
    ExerciseSeed(slug: "triceps_cuerda_tras_nuca", group: .triceps, type: .reps),
    ExerciseSeed(slug: "fondos_triceps_paralelas", group: .triceps, type: .reps),
    ExerciseSeed(slug: "fondos_triceps_maquina", group: .triceps, type: .reps),
    ExerciseSeed(slug: "fondos_triceps_banco", group: .triceps, type: .reps),
    ExerciseSeed(slug: "press_frances_barra", group: .triceps, type: .reps),
    ExerciseSeed(slug: "press_frances_mancuernas", group: .triceps, type: .reps),
    ExerciseSeed(slug: "press_frances_maquina", group: .triceps, type: .reps),
    ExerciseSeed(slug: "patada_atras_triceps_mancuerna", group: .triceps, type: .reps),
    ExerciseSeed(slug: "patada_atras_triceps_polea", group: .triceps, type: .reps),
    ExerciseSeed(slug: "extension_triceps_barraV_polea_alta", group: .triceps, type: .reps),
    ExerciseSeed(slug: "tiron_triceps_polea_prono", group: .triceps, type: .reps),
    ExerciseSeed(slug: "tiron_triceps_polea_supino", group: .triceps, type: .reps)
]

// Bíceps
let bicepsExercises: [ExerciseSeed] = [
    ExerciseSeed(slug: "curl_simultaneo_mancuernas", group: .biceps, type: .reps),
    ExerciseSeed(slug: "curl_martillo_alterno_mancuernas", group: .biceps, type: .reps),
    ExerciseSeed(slug: "curl_martillo_simultaneo_mancuernas", group: .biceps, type: .reps),
    ExerciseSeed(slug: "curl_martillo_polea_baja", group: .biceps, type: .reps),
    ExerciseSeed(slug: "curl_barra", group: .biceps, type: .reps),
    ExerciseSeed(slug: "curl_inclinado_alterno_mancuernas", group: .biceps, type: .reps),
    ExerciseSeed(slug: "curl_inclinado_simultaneo_mancuernas", group: .biceps, type: .reps),
    ExerciseSeed(slug: "curl_arana_barra", group: .biceps, type: .reps),
    ExerciseSeed(slug: "curl_arana_mancuernas", group: .biceps, type: .reps),
    ExerciseSeed(slug: "curl_concentrado", group: .biceps, type: .reps),
    ExerciseSeed(slug: "curl_banco_predicador_mancuernas", group: .biceps, type: .reps),
    ExerciseSeed(slug: "curl_banco_predicador_barra", group: .biceps, type: .reps),
    ExerciseSeed(slug: "curl_maquina", group: .biceps, type: .reps)
]

let gemeloExercises: [ExerciseSeed] = [
    ExerciseSeed(slug: "gemelo_sentado_soleo", group: .gemelo, type: .reps),
    ExerciseSeed(slug: "gemelo_prensa_horizontal", group: .gemelo, type: .reps),
    ExerciseSeed(slug: "gemelo_prensa_inclinada", group: .gemelo, type: .reps),
    ExerciseSeed(slug: "gemelo_multipower", group: .gemelo, type: .reps),
    ExerciseSeed(slug: "gemelo_una_pierna_peso", group: .gemelo, type: .reps),
    ExerciseSeed(slug: "gemelo_de_pie_maquina", group: .gemelo, type: .reps),
    ExerciseSeed(slug: "gemelo_saltos", group: .gemelo, type: .reps)
]

// Si ya tienes defaultExercises:
let defaultExercises = backExercises
    + hombroExercises
    + pechoExercises
    + femoralExercises
    + cuadricepsExercises
    + aductorExercises
    + abductorExercises
    + gluteoExercises
    + abdomenExercises
    + tricepsExercises
    + bicepsExercises
    + gemeloExercises
