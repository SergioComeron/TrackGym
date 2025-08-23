//
//  Entrenamiento.swift
//  TrackGym
//
//  Created by Sergio Comerón on 17/8/25.
//

import SwiftData
import Foundation

@Model
final class Entrenamiento {
    var id: UUID
    var startDate: Date?
    var endDate: Date?
    var gruposMusculares: [GrupoMuscular] = []
    
    @Relationship(deleteRule: .cascade)
    var ejercicios: [PerformedExercise] = []
    
    init(id: UUID = UUID(), startDate: Date? = Date(), endDate: Date? = nil) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
    }
    
    // 🔹 Helper para obtener los grupos sin duplicados y ordenados
    var gruposUnicos: [GrupoMuscular] {
        Array(Set(gruposMusculares)).sorted { $0.rawValue < $1.rawValue }
    }
    
    // 🔹 Helper para añadir/quitar un grupo muscular
    func toggle(_ grupo: GrupoMuscular) {
        if let i = gruposMusculares.firstIndex(of: grupo) {
            gruposMusculares.remove(at: i)
        } else {
            gruposMusculares.append(grupo)
        }
    }
}

enum GrupoMuscular: String, Codable, CaseIterable {
    case pecho, espalda, hombro, biceps, triceps, cuadriceps, femoral, gluteo, gemelo, abdomen, aductor, abductor
}

extension GrupoMuscular {
    /// Nombre localizado del grupo muscular para UI.
    var localizedName: String {
        NSLocalizedString("group_\(rawValue)", comment: "")
    }
}

extension Entrenamiento {
    /// Proporción de ejercicios con al menos una serie registrada (0.0 a 1.0)
    var progresoEjercicios: Double {
        guard !ejercicios.isEmpty else { return 0.0 }
        let completados = ejercicios.filter { !$0.sets.isEmpty }.count
        return Double(completados) / Double(ejercicios.count)
    }
}
