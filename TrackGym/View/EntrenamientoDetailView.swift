//
//  EntrenamientoView.swift
//  TrackGym
//
//  Created by Sergio Comerón on 17/8/25.
//

import SwiftUI
import SwiftData

struct EntrenamientoDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Bindable var entrenamiento: Entrenamiento

    private var isFinished: Bool { entrenamiento.endDate != nil }

    var body: some View {
        Form {
            Section("Inicio") {
                LabeledContent("Inicio") {
                    Text(entrenamiento.startDate.map { DateFormatter.cachedDateTime.string(from: $0) } ?? "Sin inicio")
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: - Grupos Musculares / Resumen (según estado)
            if isFinished {
                Section("Resumen") {
                    if entrenamiento.gruposMusculares.isEmpty {
                        Text("Sin grupos marcados").foregroundStyle(.secondary)
                    } else {
                        Text(entrenamiento.gruposMuscularesNoDuplicados
                            .map { title(for: $0) }
                            .joined(separator: " · "))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Section("Grupos trabajados") {
                    ForEach(GrupoMuscular.allCases, id: \.self) { grupo in
                        Toggle(title(for: grupo), isOn: binding(for: grupo))
                    }
                }
            }

            Section("Estado") {
                if let end = entrenamiento.endDate {
                    Text("Terminado el \(DateFormatter.cachedDateTime.string(from: end))")
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        entrenamiento.endDate = Date()
                        try? context.save()
                        Task {
                            await LiveActivityManager.shared.end()
                        }
                    } label: {
                        Label("Terminar entrenamiento", systemImage: "stop.circle")
                    }
                }
            }
        }
        .navigationTitle("Detalle")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("OK") { try? context.save(); dismiss() }
            }
        }
    }
    
    // MARK: - Helpers de UI para grupos
    private func binding(for grupo: GrupoMuscular) -> Binding<Bool> {
        Binding(
            get: { entrenamiento.gruposMusculares.contains(grupo) },
            set: { newValue in
                guard !isFinished else { return }
                if newValue {
                    if !entrenamiento.gruposMusculares.contains(grupo) {
                        entrenamiento.gruposMusculares.append(grupo)
                    }
                } else {
                    entrenamiento.gruposMusculares.removeAll { $0 == grupo }
                }
                try? context.save()
            }
        )
    }

    private func title(for grupo: GrupoMuscular) -> String {
        switch grupo {
        case .biceps: return "Bíceps"
        case .triceps: return "Tríceps"
        case .cuadriceps: return "Cuádriceps"
        case .femoral: return "Femoral"
        case .gluteo: return "Glúteo"
        case .gemelo: return "Gemelo"
        case .abdomen: return "Abdomen"
        case .pecho: return "Pecho"
        case .espalda: return "Espalda"
        case .hombro: return "Hombro"
        case .aductor: return "Aductor"
        case .abductor: return "Abductor"
        }
    }
}
