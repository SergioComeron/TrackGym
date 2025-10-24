//
//  EntrenamientoListView.swift
//  TrackGym
//
//  Created by Sergio Comerón on 17/8/25.
//

import SwiftUI
import SwiftData
internal import Combine

struct EntrenamientoListView: View {
    @Environment(\.modelContext) private var context

    // Al ser startDate opcional, el sort funciona pero hay que asumir que los nil irán al final.
    @Query(sort: [SortDescriptor(\Entrenamiento.startDate, order: .reverse)])
    private var entrenamientos: [Entrenamiento]

    @State private var showingAddSheet = false
    @State private var now = Date()

    private var entrenamientosPendientes: [Entrenamiento] { entrenamientos.filter { $0.startDate == nil } }
    private var entrenamientosEnCurso: [Entrenamiento] { entrenamientos.filter { $0.endDate == nil && $0.startDate != nil } }
    private var entrenamientosTerminados: [Entrenamiento] { entrenamientos.filter { $0.endDate != nil } }

    var body: some View {
        Group {
            if entrenamientosPendientes.isEmpty && entrenamientosEnCurso.isEmpty && entrenamientosTerminados.isEmpty {
                ContentUnavailableView(
                    "Sin entrenamientos",
                    systemImage: "dumbbell",
                    description: Text("Pulsa + para añadir tu primer entreno.")
                )
            } else {
                List {
                    if !entrenamientosPendientes.isEmpty {
                        Section("Pendientes") {
                            ForEach(entrenamientosPendientes) { e in
                                NavigationLink(value: AppRoute.entrenamientoDetail(e.id)) {
                                    VStack {
                                        HStack(spacing: 12) {
                                            Image(systemName: "pause.circle")
                                            VStack(alignment: .leading) {
                                                Text("Sin inicio")
                                                    .font(.headline)
                                                Text(gruposResumen(e))
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                            if tieneRecordEnAlgunaSerie(e) {
                                                Image(systemName: "flame.fill")
                                                    .foregroundStyle(.orange)
                                                    .accessibilityLabel("Récord personal en este entrenamiento")
                                            }
                                        }
                                        .padding(.vertical, 4)
                                        HStack {
                                            Spacer()
                                            Button {
                                                repetirEntrenamiento(e)
                                            } label: {
                                                HStack {
                                                    Image(systemName: "gobackward")
                                                    Text("Repetir entrenamiento")
                                                }
                                                .font(.subheadline)
                                            }
                                            .buttonStyle(.borderless)
                                            .controlSize(.regular)
                                            .help("Repetir este entrenamiento")
                                            .accessibilityLabel("Repetir entrenamiento")
                                            .disabled((e.ejercicios ?? []).isEmpty)
                                        }
                                    }
                                }
                            }
                            .onDelete { offsets in
                                delete(entrenamientosPendientes, at: offsets)
                            }
                        }
                    }

                    if !entrenamientosEnCurso.isEmpty {
                        Section("En curso") {
                            ForEach(entrenamientosEnCurso) { e in
                                NavigationLink(value: AppRoute.entrenamientoDetail(e.id)) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "clock.arrow.circlepath")
                                            VStack(alignment: .leading) {
                                                Text(fechaInicioText(e))
                                                    .font(.headline)
                                                if let start = e.startDate {
                                                    Text(elapsedText(since: start))
                                                        .font(.subheadline)
                                                        .foregroundStyle(.secondary)
                                                } else {
                                                    Text("En curso")
                                                        .font(.subheadline)
                                                        .foregroundStyle(.secondary)
                                                }
                                                Text(gruposResumen(e))
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                            if tieneRecordEnAlgunaSerie(e) {
                                                Image(systemName: "flame.fill")
                                                    .foregroundStyle(.orange)
                                                    .accessibilityLabel("Récord personal en este entrenamiento")
                                            }
                                        }
                                        .padding(.vertical, 4)
                                        HStack {
                                            Spacer()
                                            Button {
                                                repetirEntrenamiento(e)
                                            } label: {
                                                HStack {
                                                    Image(systemName: "gobackward")
                                                    Text("Repetir entrenamiento")
                                                }
                                                .font(.subheadline)
                                            }
                                            .buttonStyle(.borderless)
                                            .controlSize(.regular)
                                            .help("Repetir este entrenamiento")
                                            .accessibilityLabel("Repetir entrenamiento")
                                            .disabled((e.ejercicios ?? []).isEmpty)
                                        }
                                    }
                                }
                            }
                            .onDelete { offsets in
                                delete(entrenamientosEnCurso, at: offsets)
                            }
                        }
                    }

                    if !entrenamientosTerminados.isEmpty {
                        Section("Terminados") {
                            ForEach(entrenamientosTerminados) { e in
                                NavigationLink(value: AppRoute.entrenamientoDetail(e.id)) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "clock")
                                            VStack(alignment: .leading) {
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
                                            Spacer()
                                            if tieneRecordEnAlgunaSerie(e) {
                                                Image(systemName: "flame.fill")
                                                    .foregroundStyle(.orange)
                                                    .accessibilityLabel("Récord personal en este entrenamiento")
                                            }
                                        }
                                        .padding(.vertical, 4)
                                        HStack {
                                            Spacer()
                                            Button {
                                                repetirEntrenamiento(e)
                                            } label: {
                                                HStack {
                                                    Image(systemName: "gobackward")
                                                    Text("Repetir entrenamiento")
                                                }
                                                .font(.subheadline)
                                            }
                                            .buttonStyle(.borderless)
                                            .controlSize(.regular)
                                            .help("Repetir este entrenamiento")
                                            .accessibilityLabel("Repetir entrenamiento")
                                            .disabled((e.ejercicios ?? []).isEmpty)
                                        }
                                    }
                                }
                            }
                            .onDelete { offsets in
                                delete(entrenamientosTerminados, at: offsets)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Entrenamientos")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Añadir entrenamiento")
                .disabled(!entrenamientosEnCurso.isEmpty)
            }
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddEntrenamientoView()
                .presentationDetents([.medium, .large])
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
    }

    private func delete(_ items: [Entrenamiento], at offsets: IndexSet) {
        for index in offsets {
            context.delete(items[index])
        }
        do {
            try context.save()
            print("✅ Guardado tras borrar entrenamientos")
        } catch {
            print("❌ Error al guardar tras borrar entrenamientos: \(error)")
            context.rollback()
        }
    }

    /// Crea un nuevo entrenamiento con la misma selección de ejercicios y grupos musculares que `origen`,
    /// sin fecha de inicio (pendiente) y sin fecha de fin.
    private func repetirEntrenamiento(_ origen: Entrenamiento) {
        // Crear un nuevo entrenamiento fechado en el momento de la duplicación
        let nuevo = Entrenamiento(
            id: UUID(),
            startDate: nil,
            endDate: nil
        )

        // Duplicar la estructura de ejercicios (mismos ejercicios; sets vacíos)
        if let ejerciciosOrigen = origen.ejercicios, !ejerciciosOrigen.isEmpty {
            var clonados: [PerformedExercise] = []
            clonados.reserveCapacity(ejerciciosOrigen.count)
            for pe in ejerciciosOrigen {
                // Crear un nuevo PerformedExercise usando el inicializador disponible.
                // Ajustamos a un inicializador mínimo (por ejemplo, solo slug) y dejamos los sets vacíos si aplica.
                let nuevoPE = PerformedExercise(slug: pe.slug)
                // Si `sets` es una propiedad opcional/var en tu modelo, déjala vacía explícitamente.
                // Si no existe esta propiedad, puedes eliminar la siguiente línea sin afectar la compilación.
                nuevoPE.sets = []
                clonados.append(nuevoPE)
            }
            nuevo.ejercicios = clonados
        }

        // Copiar también los grupos musculares seleccionados
        nuevo.gruposMusculares = origen.gruposMusculares

        // Insertar y guardar
        context.insert(nuevo)
        do {
            try context.save()
            print("✅ Entrenamiento repetido correctamente: \(nuevo.id)")
        } catch {
            print("❌ Error al repetir entrenamiento: \(error)")
            context.rollback()
        }
    }

    // Helpers de presentación (modelo con opcionales)
    private func fechaInicioText(_ e: Entrenamiento) -> String {
        if let start = e.startDate {
            DateFormatter.cachedDateTime.string(from: start)
        } else {
            "Sin inicio"
        }
    }

    private func rangoFechasText(start: Date, end: Date) -> String {
        let f = DateFormatter.cachedDateTime
        return "\(f.string(from: start)) → \(f.string(from: end))"
    }

    private func elapsedText(since start: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "Lleva %02d:%02d:%02d", h, m, s)
        } else {
            return String(format: "Lleva %02d:%02d", m, s)
        }
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
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    private func gruposResumen(_ e: Entrenamiento) -> String {
        let unique = Array(Set(e.gruposMusculares))
        if unique.isEmpty { return "Sin grupos" }
        return unique.map { grupoNombre($0) }.sorted().joined(separator: " · ")
    }

    private func grupoNombre(_ g: GrupoMuscular) -> String {
        // Fallback genérico basado en el nombre del case
        let raw = String(describing: g)
        return raw.replacingOccurrences(of: "_", with: " ")
                  .replacingOccurrences(of: "-", with: " ")
                  .capitalized
    }

    private func tieneRecordEnAlgunaSerie(_ entrenamiento: Entrenamiento) -> Bool {
        // Desempaquetar ejercicios del entrenamiento (nil cuenta como vacío)
        let ejerciciosEnEntreno: [PerformedExercise] = entrenamiento.ejercicios ?? []
        guard !ejerciciosEnEntreno.isEmpty else { return false }

        for ejercicio in ejerciciosEnEntreno {
            // Buscar todos los sets de ese slug en todos los entrenamientos
            let allSets: [ExerciseSet] = entrenamientos
                .compactMap { $0.ejercicios }   // [[PerformedExercise]]
                .flatMap { $0 }                  // [PerformedExercise]
                .filter { $0.slug == ejercicio.slug }
                .compactMap { $0.sets }          // [[ExerciseSet]]?
                .flatMap { $0 }                  // [ExerciseSet]

            let maxPeso = allSets.map { $0.weight }.max() ?? 0

            // ¿Algún set de este ejercicio iguala el máximo?
            let setsEjercicio: [ExerciseSet] = ejercicio.sets ?? []
            if setsEjercicio.contains(where: { abs($0.weight - maxPeso) < 0.0001 && maxPeso > 0 }) {
                return true
            }
        }
        return false
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
    return EntrenamientoListView()
        .modelContainer(container)
}

#Preview("Con datos") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Entrenamiento.self, configurations: config)

    let ctx = container.mainContext
    // Entrenamiento terminado hace 1 hora
    ctx.insert(Entrenamiento(
        id: UUID(),
        startDate: Date().addingTimeInterval(-3600),
        endDate: Date()
    ))
    // Entrenamiento en curso de ayer
    ctx.insert(Entrenamiento(
        id: UUID(),
        startDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
        endDate: nil
    ))

    return EntrenamientoListView()
        .modelContainer(container)
}
#endif

