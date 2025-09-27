//
//  ContentView.swift
//  TrackGymWatch Watch App
//
//  Created by Sergio Comerón on 8/9/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    // Mismo orden que en iPhone: más recientes primero. Nil al final.
    @Query(sort: [SortDescriptor(\Entrenamiento.startDate, order: .reverse)])
    private var entrenamientos: [Entrenamiento]

    // Derivados simples para el watch (solo listar y navegar)
    private var entrenamientosPendientes: [Entrenamiento] { entrenamientos.filter { $0.startDate == nil } }
    private var entrenamientosEnCurso: [Entrenamiento] { entrenamientos.filter { $0.endDate == nil && $0.startDate != nil } }
    private var entrenamientosTerminados: [Entrenamiento] { entrenamientos.filter { $0.endDate != nil } }

    var body: some View {
        NavigationStack {
            if entrenamientos.isEmpty {
                ContentUnavailableView(
                    "Sin entrenamientos",
                    systemImage: "dumbbell",
                    description: Text("Crea un entrenamiento desde el iPhone.")
                )
            } else {
                List {
                    if !entrenamientosEnCurso.isEmpty {
                        Section("En curso") {
                            ForEach(entrenamientosEnCurso) { e in
                                NavigationLink(destination: EntrenamientoDetailView(entrenamiento: e)) {
                                    rowEnCurso(e)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Entrenamiento en curso. \(fechaInicioText(e)). \(gruposResumen(e))")
                            }
                        }
                    }
                    if !entrenamientosPendientes.isEmpty {
                        Section("Pendientes") {
                            ForEach(entrenamientosPendientes) { e in
                                NavigationLink(destination: EntrenamientoDetailView(entrenamiento: e)) {
                                    rowPendiente(e)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Entrenamiento pendiente. Sin inicio. \(gruposResumen(e))")
                                .accessibilityHint("Toca para ver el detalle")
                            }
                        }
                    }
                    if !entrenamientosTerminados.isEmpty {
                        Section("Terminados") {
                            ForEach(entrenamientosTerminados) { e in
                                NavigationLink(destination: EntrenamientoDetailView(entrenamiento: e)) {
                                    rowTerminado(e)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Entrenamiento en curso. \(fechaInicioText(e)). \(gruposResumen(e))")
                            }
                        }
                    }
                }
                .navigationTitle("Entrenamientos")
            }
        }
    }

    // MARK: - Row Builders (watch simplificado)
    private func rowPendiente(_ e: Entrenamiento) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "pause.circle")
            VStack(alignment: .leading, spacing: 2) {
                Text("Sin inicio")
                    .font(.headline)
                Text(gruposResumen(e))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private func rowEnCurso(_ e: Entrenamiento) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
            VStack(alignment: .leading, spacing: 2) {
                Text(fechaInicioText(e))
                    .font(.headline)
                Text("En curso")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(gruposResumen(e))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private func rowTerminado(_ e: Entrenamiento) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
            VStack(alignment: .leading, spacing: 2) {
                Text(fechaInicioText(e))
                    .font(.headline)
                if let end = e.endDate, let start = e.startDate {
                    Text("Inicio " + horaSoloText(start) + " · Duración " + duracionText(from: start, to: end))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(gruposResumen(e))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers (copiados/simplificados del iPhone)
    private func fechaInicioText(_ e: Entrenamiento) -> String {
        if let start = e.startDate { DateFormatter.cachedDateTime.string(from: start) } else { "Sin inicio" }
    }

    private func horaSoloText(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.timeStyle = .short
        df.dateStyle = .none
        return df.string(from: date)
    }

    private func duracionText(from start: Date, to end: Date) -> String {
        let seconds = max(0, Int(end.timeIntervalSince(start)))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%02d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    private func gruposResumen(_ e: Entrenamiento) -> String {
        let unique = Array(Set(e.gruposMusculares))
        if unique.isEmpty { return "Sin grupos" }
        return unique.map { grupoNombre($0) }.sorted().joined(separator: " · ")
    }

    private func grupoNombre(_ g: GrupoMuscular) -> String {
        let raw = String(describing: g)
        return raw.replacingOccurrences(of: "_", with: " ")
                  .replacingOccurrences(of: "-", with: " ")
                  .capitalized
    }
}

// DateFormatter cache sencillo
extension DateFormatter {
    static let cachedDateTime: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df
    }()
}

#if DEBUG
#Preview("Vacío") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Entrenamiento.self, configurations: config)
    return ContentView()
        .modelContainer(container)
}

#Preview("Con datos") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Entrenamiento.self, configurations: config)

    let ctx = container.mainContext
    // Pendiente (sin inicio)
    ctx.insert(Entrenamiento(
        id: UUID(),
        startDate: nil,
        endDate: nil
    ))
    // En curso (iniciado, sin fin)
    ctx.insert(Entrenamiento(
        id: UUID(),
        startDate: Date().addingTimeInterval(-1800),
        endDate: nil
    ))
    // Terminado (con inicio y fin)
    ctx.insert(Entrenamiento(
        id: UUID(),
        startDate: Date().addingTimeInterval(-7200),
        endDate: Date().addingTimeInterval(-3600)
    ))

    return ContentView()
        .modelContainer(container)
}
#endif
