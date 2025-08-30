//
//  EntrenamientoView.swift
//  TrackGym
//
//  Created by Sergio Comerón on 17/8/25.
//

import SwiftUI
import SwiftData
import FoundationModels
import Foundation
#if canImport(Charts)
import Charts
#endif

struct EntrenamientoDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Bindable var entrenamiento: Entrenamiento
    @State private var isShowingExercisePicker = false
    @State private var isGroupSectionExpanded = false
    @State private var selectedExercise: PerformedExercise?

    private var isFinished: Bool { entrenamiento.endDate != nil }

    @Query(sort: [SortDescriptor(\Entrenamiento.startDate, order: .reverse)])
    private var entrenamientos: [Entrenamiento]

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
                        Text(entrenamiento.gruposUnicos
                            .map { $0.localizedName }
                            .joined(separator: " · "))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Section {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isGroupSectionExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Text("Grupos musculares")
                            Spacer()
                            Image(systemName: isGroupSectionExpanded ? "chevron.down" : "chevron.right")
                                .foregroundStyle(.secondary)
                                .animation(.easeInOut(duration: 0.2), value: isGroupSectionExpanded)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isGroupSectionExpanded ? "Ocultar grupos musculares" : "Mostrar grupos muscululares")

                    if !isGroupSectionExpanded && !entrenamiento.gruposMusculares.isEmpty {
                        Text(entrenamiento.gruposMusculares.map { $0.localizedName }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                    
                    if !isGroupSectionExpanded && entrenamiento.gruposMusculares.isEmpty {
                        Text("Despliega para añadir")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }

                    if isGroupSectionExpanded {
                        ForEach(GrupoMuscular.allCases, id: \.self) { grupo in
                            Toggle(grupo.localizedName, isOn: binding(for: grupo))
                        }
                    }
                } header: {
                    EmptyView()
                }
            }

            // MARK: - Ejercicios realizados
            Section("Ejercicios") {
                if uniqueEjercicios.isEmpty {
                    Text("Aún no has añadido ejercicios")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(uniqueEjercicios) { pe in
                        Button {
                            selectedExercise = pe
                        } label: {
                            ExerciseRowView(pe: pe, entrenamientos: entrenamientos)
                        }
                    }
                    .onDelete(perform: removePerformedExercises)
                    .onMove(perform: movePerformedExercises)
                }

                if !isFinished {
                    Button {
                        isShowingExercisePicker = true
                    } label: {
                        Label("Añadir ejercicio", systemImage: "plus.circle.fill")
                    }
                }
            }

            Section("Estado") {
                if entrenamiento.startDate == nil {
                    Button {
                        entrenamiento.startDate = Date()
                        try? context.save()
                        
                        Task {
                            await LiveActivityManager.shared.start(
                                title: "Entrenamiento",
                                startedAt: entrenamiento.startDate ?? Date(),
                                entrenamientoID: entrenamiento.id,
                                progress: entrenamiento.progresoEjercicios
                            )
                        }
                    } label: {
                        Label("Empezar entrenamiento", systemImage: "play.fill")
                    }
                    Text("El entrenamiento aún no ha comenzado. Puedes preparar ejercicios o grupos.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if let end = entrenamiento.endDate {
                    Text("Terminado el \(DateFormatter.cachedDateTime.string(from: end))")
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        entrenamiento.endDate = Date()
                        cleanupDuplicates()
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
                if !isFinished {
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $isShowingExercisePicker) {
            ExercisePickerView(
                available: filteredCatalogForCurrentGroups(),
                onPick: { seed in
                    addExerciseSafely(slug: seed.slug)
                }
            )
        }
        .navigationDestination(item: $selectedExercise) { exercise in
            ExerciseSetsEditorView(performedExercise: exercise, isFinished: entrenamiento.endDate != nil)
        }
//        .onAppear {
//            print("🔍 OnAppear - Estado INICIAL:")
//            for (i, ejercicio) in entrenamiento.ejercicios.enumerated() {
//                print("  [\(i)] \(ejercicio.slug) - order: \(ejercicio.order) - id: \(ejercicio.id)")
//            }
//            
//            // COMENTAR TEMPORALMENTE la migración para aislar el problema
//             migrateLegacyExerciseOrderIfNeeded()
//            
//            print("🔍 OnAppear - Estado FINAL:")
//            for (i, ejercicio) in entrenamiento.ejercicios.enumerated() {
//                print("  [\(i)] \(ejercicio.slug) - order: \(ejercicio.order) - id: \(ejercicio.id)")
//            }
//        }
    }
    
    // MARK: - Computed property para ejercicios únicos
    private var uniqueEjercicios: [PerformedExercise] {
        let sorted = entrenamiento.ejercicios.sorted(by: { $0.order < $1.order })
//        print("🔍 uniqueEjercicios - Ejercicios ordenados:")
//        for (i, ejercicio) in sorted.enumerated() {
//            print("  [\(i)] \(ejercicio.slug) - order: \(ejercicio.order)")
//        }
        return sorted
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

    // MARK: - Helpers de ejercicios (mejorados para CloudKit)
    private func filteredCatalogForCurrentGroups() -> [ExerciseSeed] {
        let selectedGroups = Set(entrenamiento.gruposMusculares)
        
        guard !selectedGroups.isEmpty else { return [] }
        
        // Filtrar ejercicios ya añadidos para evitar duplicados en la UI
        let existingSlugs = Set(entrenamiento.ejercicios.map { $0.slug })
        
        return defaultExercises.filter { exercise in
            selectedGroups.contains(exercise.group) && !existingSlugs.contains(exercise.slug)
        }
    }

    private func addExerciseSafely(slug: String) {
        guard !isFinished else { return }
        
        // Doble verificación más robusta
        let existingExercise = entrenamiento.ejercicios.first { $0.slug == slug }
        guard existingExercise == nil else {
            print("⚠️ Ejercicio \(slug) ya existe, evitando duplicado")
            return
        }
        
        // Crear con ID único para CloudKit
        let pe = PerformedExercise(slug: slug, entrenamiento: entrenamiento)
        pe.id = UUID()
        pe.order = (entrenamiento.ejercicios.map { $0.order }.max() ?? -1) + 1
        
        context.insert(pe)
        entrenamiento.ejercicios.append(pe)
        
        // RENUMERAR order tras añadir ejercicio (no se especificó sets aquí, pero se recomienda coherencia)
        // (No sets renumerado aquí porque sets están en ExerciseSetsEditorView)
        
        do {
            try context.save()
            print("✅ Ejercicio \(slug) añadido correctamente")
        } catch {
            print("❌ Error al guardar ejercicio: \(error)")
            // Revertir cambios si falla el guardado
            context.rollback()
        }
    }

    private func removePerformedExercises(at offsets: IndexSet) {
        let exercisesToRemove = offsets.map { entrenamiento.ejercicios[$0] }
        
        for pe in exercisesToRemove {
            context.delete(pe)
        }
        
        entrenamiento.ejercicios.remove(atOffsets: offsets)
        
        do {
            try context.save()
        } catch {
            print("❌ Error al eliminar ejercicios: \(error)")
            context.rollback()
        }
        
        // Reenumerar los órdenes después de borrar para mantener el orden limpio tras eliminar
        let ejerciciosOrdenados = entrenamiento.ejercicios.sorted { $0.order < $1.order }
        for (idx, ejercicio) in ejerciciosOrdenados.enumerated() {
            ejercicio.order = idx
        }
        entrenamiento.ejercicios = ejerciciosOrdenados
        try? context.save()
    }
    
    private func movePerformedExercises(from source: IndexSet, to destination: Int) {
//        print("🔧 Iniciando movimiento agresivo...")
        
        var ejerciciosOrdenados = entrenamiento.ejercicios.sorted { $0.order < $1.order }
        ejerciciosOrdenados.move(fromOffsets: source, toOffset: destination)
        
        // Actualizar los values de 'order'
        for (idx, ejercicio) in ejerciciosOrdenados.enumerated() {
            ejercicio.order = idx
//            print("🔧 Actualizando \(ejercicio.slug) order = \(idx)")
        }
        
        // 🔑 VERSIÓN AGRESIVA: Vaciar completamente y reconstruir
        let ejerciciosReordenados = ejerciciosOrdenados
//        print("🔧 Vaciando array...")
        entrenamiento.ejercicios.removeAll()
        
        // Primer guardado (array vacío)
        do {
            try context.save()
            print("✅ Array vaciado y guardado")
        } catch {
            print("❌ Error al vaciar: \(error)")
            context.rollback()
            return
        }
        
        // Reconstruir con el orden correcto
//        print("🔧 Reconstruyendo array en orden correcto...")
        entrenamiento.ejercicios = ejerciciosReordenados
        
        // Segundo guardado (array reordenado)
        do {
            try context.save()
//            print("✅ Array reconstruido y guardado")
            
            // Verificación final
//            print("🔍 Verificación post-reconstrucción:")
//            for (i, ejercicio) in entrenamiento.ejercicios.enumerated() {
//                print("  [\(i)] \(ejercicio.slug) - order: \(ejercicio.order)")
//            }
        } catch {
            print("❌ Error al guardar reconstrucción: \(error)")
            context.rollback()
        }
    }
    
    // MARK: - Limpieza de duplicados (crucial para CloudKit)
    private func cleanupDuplicates() {
        let slugGroups = Dictionary(grouping: entrenamiento.ejercicios) { $0.slug }
        var exercisesToDelete: [PerformedExercise] = []
        
        for (slug, exercises) in slugGroups where exercises.count > 1 {
            print("🔧 Encontrados \(exercises.count) duplicados para \(slug)")
            
            // Mantener el más reciente (por fecha de creación)
            let sortedExercises = exercises.sorted { first, second in
                let firstDate = first.createdAt
                let secondDate = second.createdAt
                return firstDate > secondDate
            }
            
            // Marcar para eliminación todos excepto el primero
            exercisesToDelete.append(contentsOf: Array(sortedExercises.dropFirst()))
        }
        
        // Eliminar duplicados
        for exercise in exercisesToDelete {
            if let index = entrenamiento.ejercicios.firstIndex(of: exercise) {
                entrenamiento.ejercicios.remove(at: index)
            }
            context.delete(exercise)
        }
        
        if !exercisesToDelete.isEmpty {
            print("🗑️ Eliminados \(exercisesToDelete.count) ejercicios duplicados")
        }
    }
    
    private func cleanupDuplicatesInMemory() {
        let uniqueExercises = entrenamiento.ejercicios.reduce(into: [String: PerformedExercise]()) { result, exercise in
            if result[exercise.slug] == nil {
                result[exercise.slug] = exercise
            }
        }
        
        if uniqueExercises.count != entrenamiento.ejercicios.count {
            entrenamiento.ejercicios = Array(uniqueExercises.values)
        }
    }
    
    /// Migra ejercicios antiguos asignándoles un 'order' secuencial según la fecha de creación si el campo no está bien definido.
    private func migrateLegacyExerciseOrderIfNeeded() {
        let ejercicios = entrenamiento.ejercicios
        
        // Solo migrar si realmente hay un problema
        let hasInvalidOrder = ejercicios.isEmpty ||
                             Set(ejercicios.map { $0.order }).count != ejercicios.count ||
                             ejercicios.allSatisfy { $0.order == 0 }
        
        guard hasInvalidOrder else {
            print("✅ Orden ya es válido, no se necesita migración")
            return
        }
        
//        print("🔧 Migrando orden legacy...")
        
        // Ordenar por fecha de creación y asignar order
        let sorted = ejercicios.sorted { $0.createdAt < $1.createdAt }
        for (idx, ejercicio) in sorted.enumerated() {
            ejercicio.order = idx
        }
        
        // Usar el mismo método agresivo para persistir
        entrenamiento.ejercicios.removeAll()
        
        do {
            try context.save()
            entrenamiento.ejercicios = sorted
            try context.save()
            print("✅ Migración completada")
        } catch {
            print("❌ Error en migración: \(error)")
            context.rollback()
        }
    }
    
}

// Nueva función asíncrona justo antes de ExerciseSetsEditorView
private func suggestNextReps(for performedExercise: PerformedExercise, setsHistoricos: [ExerciseSet], perfilObjetivo: String? = nil, exerciseName: String? = nil, exerciseGroup: String? = nil) async -> Int {
    let model = SystemLanguageModel.default
    guard model.availability == .available else {
        // Fallback por objetivo
        let objetivo = (perfilObjetivo ?? "Ganar músculo").lowercased()
        if objetivo.contains("fuerza") { return 5 }
        if objetivo.contains("resisten") || objetivo.contains("endurance") { return 15 }
        return 12
    }

    // Determinar rango por objetivo
    let objetivo = (perfilObjetivo ?? "Ganar músculo").lowercased()
    let baseRange: (Int, Int)
    if objetivo.contains("fuerza") { baseRange = (3, 6) }
    else if objetivo.contains("resisten") || objetivo.contains("endurance") { baseRange = (12, 20) }
    else { baseRange = (8, 15) } // hipertrofia por defecto

    let lastReps = setsHistoricos.last?.reps ?? 0

    // Infer isolation/compound for stepCap
    let groupLower = (exerciseGroup ?? "").lowercased()
    let isIsolation = groupLower.contains("bíceps") || groupLower.contains("biceps") || groupLower.contains("tríceps") || groupLower.contains("triceps") || groupLower.contains("gemelo") || groupLower.contains("abdomen") || groupLower.contains("antebrazo")
    let stepCap = isIsolation ? 1 : 2

    let minAllowed = max(baseRange.0, lastReps == 0 ? baseRange.0 : lastReps - stepCap)
    let maxAllowed = min(baseRange.1, lastReps == 0 ? baseRange.1 : lastReps + stepCap)

    // Intra-session fatigue tweak: reduce maxAllowed by 1 if 3+ sets (not below minAllowed)
    let setIndex = performedExercise.sets.count
    let minA = minAllowed
    var maxA = maxAllowed
    if setIndex >= 3 { maxA = max(minA, maxA - 1) }

    let nombre = exerciseName ?? performedExercise.slug
    let grupo = exerciseGroup != nil ? " (grupo: \(exerciseGroup!))" : ""
    let recentReps = setsHistoricos.suffix(5).map { $0.reps }
    let summary = recentReps.isEmpty ? "sin historial" : recentReps.map(String.init).joined(separator: ", ")

    let prompt = """
    TAREA: Próxima serie → devuelve solo un número entero (reps).
    EJERCICIO: \(nombre)\(grupo)
    HISTÓRICO REPS RECIENTES: [\(summary)]
    OBJETIVO: \(perfilObjetivo ?? "Ganar músculo") (rango objetivo: \(baseRange.0)–\(baseRange.1))
    SERIE ACTUAL: \(setIndex + 1)
    POLÍTICA:
    - Si la última serie fue muy fácil (≥ techo del rango), sugiere +1 dentro de rango.
    - Si fue muy dura (≤ suelo del rango), sugiere −1 dentro de rango.
    - Si estuvo dentro, mantén.
    RANGO PERMITIDO (reps): min=\(minA), max=\(maxA)
    PASO MÁXIMO vs ÚLTIMO USADO: ±\(stepCap) reps
    FORMATO: solo el número entero (ej. 12)
    """

    let instrucciones = """
    Eres un entrenador personal estricto. Devuelves solo un número entero (reps).
    REGLAS DURAS:
    - Nunca propongas repeticiones fuera del rango permitido que recibe el prompt.
    - No cambies más de \(stepCap) reps respecto a la última serie si existe histórico.
    - Ajusta el peso en función del rango objetivo de repeticiones: por encima del rango ⇒ subir; por debajo ⇒ bajar; dentro ⇒ mantener o micro-ajustar.
    - Si no hay datos suficientes, elige un valor centrado del rango objetivo.
    - Responde solo el número, sin texto ni unidades.
    """

    do {
        let session = LanguageModelSession(instructions: instrucciones)
        let response = try await session.respond(to: prompt)
        let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        // Extraer primer entero del contenido
        let regex = try? NSRegularExpression(pattern: #"(\b\d{1,3}\b)"#)
        if let match = regex?.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range(at: 1), in: content),
           let num = Int(content[range]) {
            let clamped = min(max(num, minA), maxA)
            return clamped
        }
    } catch {
        print("❌ Error consultando sugerencia reps: \(error)")
    }

    // Fallback: prefer lastReps if available, else midpoint (rounded) of allowed range, biased to baseRange if needed
    let mid = (minA + maxA) / 2
    if lastReps > 0 { return max(minA, min(maxA, lastReps)) }
    return max(baseRange.0, min(baseRange.1, mid))
}

private func suggestNextWeight(for performedExercise: PerformedExercise, setsHistoricos: [ExerciseSet], perfilObjetivo: String? = nil, exerciseName: String? = nil, exerciseGroup: String? = nil) async -> Double {
    // Si Apple Intelligence (Foundation Models) está disponible
    let model = SystemLanguageModel.default
    guard model.availability == .available else {
        // Fallback: último peso o 50
        return setsHistoricos.last?.weight ?? 50.0
    }

    // --- Cálculo de límites de seguridad ---
    let last = setsHistoricos.last?.weight ?? 50.0
    let maxHist = setsHistoricos.map { $0.weight }.max() ?? last
    let stepCap = max(2.5, last * 0.10)
    let minAllowed = max(0.0, last - stepCap)
    let maxAllowed = min(maxHist * 1.20, last + stepCap, 200.0)

    // --- Objetivo-driven rep range and local rule ---
    let objetivo = perfilObjetivo ?? "Ganar músculo"
    let objetivoLower = objetivo.lowercased()
    let repRange: (Int, Int)
    if objetivoLower.contains("fuerza") { repRange = (3, 6) }
    else if objetivoLower.contains("resisten") || objetivoLower.contains("endurance") { repRange = (12, 20) }
    else { repRange = (8, 15) }

    let nombre = exerciseName ?? performedExercise.slug
    let grupo = exerciseGroup != nil ? " (grupo: \(exerciseGroup!))" : ""
    let groupLower = (exerciseGroup ?? "").lowercased()
    let isIsolation = groupLower.contains("bíceps") || groupLower.contains("biceps") || groupLower.contains("tríceps") || groupLower.contains("triceps") || groupLower.contains("gemelo") || groupLower.contains("abdomen") || groupLower.contains("antebrazo")
    let plateStep: Double = isIsolation ? 1.0 : 2.5
    let pct: Double = objetivoLower.contains("fuerza") ? 0.05 : (objetivoLower.contains("resisten") ? 0.02 : 0.03)
    let inc: Double = max(plateStep, last * pct)

    // Intra-session logic: use current set reps and weight
    let currentSetsSorted = performedExercise.sets.sorted { $0.order < $1.order }
    let lastCurrentReps = currentSetsSorted.last?.reps
    var proposed = last
    if let lastCurrentReps = lastCurrentReps {
        if lastCurrentReps >= repRange.1 { proposed = last + inc }
        else if lastCurrentReps < repRange.0 { proposed = max(0.0, last - inc) }
        else { proposed = last }
    }
    let proposedClamped = min(max(proposed, minAllowed), maxAllowed)

    let lastWeights = setsHistoricos.suffix(5).map { $0.weight }
    let reps = setsHistoricos.last?.reps ?? 10
    let summary = lastWeights.isEmpty ? "sin historial" : lastWeights.map { String(format: "%.1f", $0) }.joined(separator: ", ")
    let setIndex = performedExercise.sets.count
    let prompt = """
    TAREA: Próxima serie → devuelve solo un número (kg).
    EJERCICIO: \(nombre)\(grupo)
    HISTÓRICO KILOS RECIENTES: [\(summary)]
    REPS RECIENTES (última serie actual): \(currentSetsSorted.last?.reps ?? reps)
    OBJETIVO: \(objetivo) ⇒ rango objetivo de reps: \(repRange.0)–\(repRange.1)
    SERIE ACTUAL (en esta sesión): \(setIndex + 1)
    POLÍTICA:
    - Si la última serie estuvo por ENCIMA del rango objetivo, sube ligeramente el peso.
    - Si la última serie estuvo por DEBAJO, baja ligeramente el peso.
    - Si estuvo DENTRO, mantén el peso o micro-ajuste.
    RANGO PERMITIDO (kg): min=\(String(format: "%.1f", minAllowed)), max=\(String(format: "%.1f", maxAllowed))
    SUGERENCIA INICIAL (no obligatoria): \(String(format: "%.1f", proposedClamped))
    PASO MÁXIMO vs ÚLTIMO USADO: ±10%
    FORMATO: solo el número con 1 decimal (ej. 37.5)
    """
    print(prompt)

    let instrucciones = """
    Eres un entrenador personal estricto. Devuelves solo un número en kg (máx 1 decimal).
    REGLAS DURAS:
    - Nunca propongas pesos fuera del rango permitido que recibe en el prompt.
    - No superes el 120% del máximo histórico.
    - Si no hay historial suficiente, sugiere el último peso ±10% como máximo.
    - Ajusta el peso en función del rango objetivo de repeticiones: por encima del rango ⇒ subir; por debajo ⇒ bajar; dentro ⇒ mantener o micro-ajustar.
    - Responde solo el número, sin texto ni unidades.
    """

    do {
        let session = LanguageModelSession(instructions: instrucciones)
        let response = try await session.respond(to: prompt)
        let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        // Extraer el número del string (puede traer texto)
        // Primero, intentar extraer el primer número válido (permite decimales y coma/punto)
        let regex = try? NSRegularExpression(pattern: #"([0-9]+([.,][0-9])?)"#)
        if let match = regex?.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range(at: 1), in: content) {
            let numString = content[range].replacingOccurrences(of: ",", with: ".")
            if let num = Double(numString) {
                let safe = min(max(num, minAllowed), maxAllowed)
                return safe
            }
        }
        // Fallback: intentar parsing directo
        if let num = Double(content.replacingOccurrences(of: ",", with: ".")) {
            let safe = min(max(num, minAllowed), maxAllowed)
            return safe
        }
    } catch {
        print("❌ Error consultando sugerencia peso: \(error)")
    }
    // Fallback: prefer the proposedClamped value if model output is missing or off
    return proposedClamped
}

// MARK: - ExercisePickerView
private struct ExercisePickerView: View {
    let available: [ExerciseSeed]
    var onPick: (ExerciseSeed) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(available, id: \.slug) { seed in
                Button {
                    onPick(seed)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(seed.name).font(.body)
                        Text(seed.desc).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Elegir ejercicio")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}

// MARK: - ExerciseSetsEditorView
private struct ExerciseSetsEditorView: View {
    @Environment(\.modelContext) private var context

    @Bindable var performedExercise: PerformedExercise
    let isFinished: Bool

    // Estados locales para reps, weight y duration string (por índice)
    @State private var repsStrings: [String] = []
    @State private var weightStrings: [String] = []
    @State private var durationStrings: [String] = []
    @State private var isSuggestingWeight = false

    @Query(sort: [SortDescriptor(\Entrenamiento.startDate, order: .reverse)])
    private var entrenamientos: [Entrenamiento]
    
    @Query
    private var perfiles: [Perfil]

    var body: some View {
        
        let exerciseSeed = defaultExercises.first(where: { $0.slug == performedExercise.slug })
        let exerciseType = exerciseSeed?.type ?? .reps
        
        let setsHistoricos = entrenamientos.flatMap { $0.ejercicios }
            .filter { $0.slug == performedExercise.slug }
            .flatMap { $0.sets }
        
        // Nueva declaración simplificada fuera del VStack header
        let setMax = setsHistoricos.max(by: { $0.weight < $1.weight })
        let peMax = setMax?.performedExercise
        let entrenoMax = peMax.flatMap { pe in entrenamientos.first(where: { $0.ejercicios.contains(pe) }) }
        let fechaMax = entrenoMax?.startDate
        let entrenamientosAnteriores = entrenamientos.filter { $0.ejercicios.contains(where: { $0.slug == performedExercise.slug }) && $0 != performedExercise.entrenamiento }.sorted { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }
        let anterior = entrenamientosAnteriores.first
        let fechaAnt = anterior?.startDate
        // Ordenar las series de la última sesión previa por fecha (createdAt) ascendente
        let anteriorSets: [ExerciseSet] = anterior?
            .ejercicios
            .filter { $0.slug == performedExercise.slug }
            .flatMap { $0.sets.sorted { $0.createdAt < $1.createdAt } } ?? []

        // Nuevo: determinar si es editable (tiene startDate y no está finalizado)
        let isEditable = performedExercise.entrenamiento?.startDate != nil && !isFinished
        
        VStack(alignment: .leading) {
            
            List {
                Section(header:
                    VStack(alignment: .leading, spacing: 8) {
                        Text(exerciseSeed?.name ?? performedExercise.slug)
                            .font(.title3).bold()
                            .padding(.bottom, 2)
                        if let desc = exerciseSeed?.desc {
                            Text(desc)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 2)
                        }
                        if let setMax, let fechaMax {
                            Label("Récord histórico: \(setMax.reps)x\(formatPeso(setMax.weight)) kg", systemImage: "flame.fill")
                                .font(.subheadline)
                            Text(formatDateShort(fechaMax))
                                .italic().font(.caption)
                        }
                        if let fechaAnt, !anteriorSets.isEmpty {
                            Text("Última sesión previa el \(formatDateShort(fechaAnt)):").font(.subheadline)
                            ForEach(anteriorSets.sorted(by: { $0.createdAt < $1.createdAt }), id: \.id) { set in
                                Text("\(set.reps)x\(formatPeso(set.weight)) kg")
                                    .font(.caption)
                            }
                        }
                        if setsHistoricos.isEmpty {
                            HStack {
                                Label("Nunca has registrado este ejercicio", systemImage: "exclamationmark.triangle.fill")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        }
                        Divider()
                    }
                ) {
                    // Mostrar sets ORDENADOS por 'order' ascendente para coherencia visual
                    let sortedSets = performedExercise.sets.sorted(by: { $0.order < $1.order })
                    ForEach(Array(sortedSets.enumerated()), id: \.element.id) { index, set in
                        HStack {
                            Text("Serie \(index + 1):")
                            Spacer()
                            if exerciseType == .duration {
                                TextField("Duración (seg)", text: Binding(
                                    get: {
                                        if index < durationStrings.count {
                                            return durationStrings[index]
                                        }
                                        return ""
                                    },
                                    set: { newValue in
                                        let filtered = newValue.filter { "0123456789".contains($0) }
                                        let limited = String(filtered.prefix(4))
                                        if index < durationStrings.count {
                                            durationStrings[index] = limited
                                        }
                                    }
                                ))
                                .disabled(!isEditable)
                                .keyboardType(.numberPad)
                                .frame(width: 70)
                                .multilineTextAlignment(.trailing)
                                .onChange(of: durationStrings) {
                                    let sortedSets = performedExercise.sets.sorted(by: { $0.order < $1.order })
                                    guard index < sortedSets.count else { return }
                                    if let intValue = Int(durationStrings[safe: index] ?? ""), intValue >= 0 {
                                        sortedSets[index].duration = intValue
                                        saveContext()
                                    }
                                }
                                Text("seg")

                                TextField("Peso", text: Binding(
                                    get: {
                                        if index < weightStrings.count {
                                            return weightStrings[index]
                                        }
                                        return ""
                                    },
                                    set: { newValue in
                                        let filtered = newValue.filter { "0123456789.,".contains($0) }
                                        let normalized = filtered.replacingOccurrences(of: ",", with: ".")
                                        let limited = String(normalized.prefix(6))
                                        if index < weightStrings.count {
                                            weightStrings[index] = limited
                                        }
                                    }
                                ))
                                .disabled(!isEditable)
                                .keyboardType(.decimalPad)
                                .frame(width: 70)
                                .multilineTextAlignment(.trailing)
                                .onChange(of: weightStrings) {
                                    let sortedSets = performedExercise.sets.sorted(by: { $0.order < $1.order })
                                    guard index < sortedSets.count else { return }
                                    let valueString = weightStrings[safe: index]?.replacingOccurrences(of: ",", with: ".") ?? ""
                                    if let doubleValue = Double(valueString), doubleValue >= 0 {
                                        sortedSets[index].weight = doubleValue
                                        saveContext()
                                    }
                                }
                                Text("kg")
                            } else {
                                TextField("Reps", text: Binding(
                                    get: {
                                        if index < repsStrings.count {
                                            return repsStrings[index]
                                        }
                                        return ""
                                    },
                                    set: { newValue in
                                        let filtered = newValue.filter { "0123456789".contains($0) }
                                        let limited = String(filtered.prefix(3))
                                        if index < repsStrings.count {
                                            repsStrings[index] = limited
                                        }
                                    }
                                ))
                                .disabled(!isEditable)
                                .keyboardType(.numberPad)
                                .frame(width: 50)
                                .multilineTextAlignment(.trailing)
                                .onChange(of: repsStrings) {
                                    let sortedSets = performedExercise.sets.sorted(by: { $0.order < $1.order })
                                    guard index < sortedSets.count else { return }
                                    if let intValue = Int(repsStrings[safe: index] ?? ""), intValue >= 0 {
                                        sortedSets[index].reps = intValue
                                        saveContext()
                                    }
                                }
                                Text("reps")
                                TextField("Peso", text: Binding(
                                    get: {
                                        if index < weightStrings.count {
                                            return weightStrings[index]
                                        }
                                        return ""
                                    },
                                    set: { newValue in
                                        let filtered = newValue.filter { "0123456789.,".contains($0) }
                                        let normalized = filtered.replacingOccurrences(of: ",", with: ".")
                                        let limited = String(normalized.prefix(6))
                                        if index < weightStrings.count {
                                            weightStrings[index] = limited
                                        }
                                    }
                                ))
                                .disabled(!isEditable)
                                .keyboardType(.decimalPad)
                                .frame(width: 70)
                                .multilineTextAlignment(.trailing)
                                .onChange(of: weightStrings) {
                                    let sortedSets = performedExercise.sets.sorted(by: { $0.order < $1.order })
                                    guard index < sortedSets.count else { return }
                                    let valueString = weightStrings[safe: index]?.replacingOccurrences(of: ",", with: ".") ?? ""
                                    if let doubleValue = Double(valueString), doubleValue >= 0 {
                                        sortedSets[index].weight = doubleValue
                                        saveContext()
                                    }
                                }
                                Text("kg")
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .onDelete(perform: deleteSets)
                    
                    if isSuggestingWeight {
                        HStack {
                            ProgressView()
                            Text("Calculando sugerencia de peso...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
#if canImport(Charts)
                Section {
                    let currentSets = performedExercise.sets.sorted { $0.order < $1.order }
                    let historicalMax = setsHistoricos.max(by: { $0.weight < $1.weight })?.weight ?? 0
                    let historicalMin = setsHistoricos.min(by: { $0.weight < $1.weight })?.weight ?? 0
                    if !currentSets.isEmpty {
                        Chart {
                            if historicalMax > 0 {
                                RuleMark(y: .value("Peso máximo", historicalMax))
                                    .foregroundStyle(.green)
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2,2]))
                            }
                            if historicalMin > 0 && historicalMin != historicalMax {
                                RuleMark(y: .value("Peso mínimo", historicalMin))
                                    .foregroundStyle(.orange)
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2,2]))
                            }
                            ForEach(Array(currentSets.enumerated()), id: \.element.id) { idx, set in
                                PointMark(
                                    x: .value("Serie", idx),
                                    y: .value("Peso registrado", set.weight)
                                )
                                .symbolSize(70)
                                .foregroundStyle(Color.accentColor)
                            }
                        }
                        .frame(height: 180)
                        .chartYAxisLabel("kg", position: .trailing, alignment: .center)
                        .padding(.vertical, 8)
                    } else {
                        Text("Añade series para ver tu progreso de peso aquí.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Progreso de peso en esta sesión")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
#endif
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    if !isFinished && (performedExercise.entrenamiento?.startDate != nil) {
                        Button {
                            Task {
                                isSuggestingWeight = true
                                defer { isSuggestingWeight = false }
                                await addSet()
                            }
                        } label: {
                            Label("+", systemImage: "sparkles")
                        }
                        .disabled(isSuggestingWeight)
                        if let lastSetToRepeat = getLastSetToRepeat() {
                            Button {
                                repeatLastSet(lastSet: lastSetToRepeat)
                            } label: {
                                Text("+")
                            }
                            .disabled(isSuggestingWeight)
                        }
                    }
                }
            }
        }
        .onAppear {
            ensureProperOrdering()
            syncStringsWithModel()
        }
        .onChange(of: performedExercise.sets) {
            syncStringsWithModel()
        }
        .onDisappear {
            saveContext()
        }
    }

    // Función auxiliar para obtener la última serie (en este u otros entrenamientos) para repetir
    private func getLastSetToRepeat() -> ExerciseSet? {
        let allSets = entrenamientos.flatMap { $0.ejercicios }
            .filter { $0.slug == performedExercise.slug }
            .flatMap { $0.sets }
            .sorted { $0.createdAt > $1.createdAt }
        return allSets.first
    }
    
    // Función auxiliar para repetir la última serie copiada
    private func repeatLastSet(lastSet: ExerciseSet) {
        let newOrder = (performedExercise.sets.map { $0.order }.max() ?? -1) + 1
        let newSet = ExerciseSet(
            reps: lastSet.reps,
            weight: lastSet.weight,
            order: newOrder,
            performedExercise: performedExercise,
            createdAt: Date()
        )
        newSet.id = UUID()
        newSet.duration = lastSet.duration
        context.insert(newSet)
        performedExercise.sets.append(newSet)
        // RENUMERAR order por coherencia visual
        let sorted = performedExercise.sets.sorted(by: { $0.createdAt < $1.createdAt })
        for (idx, set) in sorted.enumerated() { set.order = idx }
        saveContext()
        syncStringsWithModel()
        actualizarProgresoLiveActivity()
    }

    // Sincroniza los arrays de String con los valores actuales del modelo
    // Se usa el array ordenado por 'order' ascendente para reflejar correctamente Serie 1 arriba, Serie N abajo
    private func syncStringsWithModel() {
        let sortedSets = performedExercise.sets.sorted(by: { $0.order < $1.order })
        let newRepsStrings = sortedSets.map { String($0.reps) }
        let newWeightStrings = sortedSets.map { String(format: "%.1f", $0.weight) }
        let newDurationStrings = sortedSets.map { String($0.duration) }
        
        if newRepsStrings != repsStrings {
            repsStrings = newRepsStrings
        }
        if newWeightStrings != weightStrings {
            weightStrings = newWeightStrings
        }
        if newDurationStrings != durationStrings {
            durationStrings = newDurationStrings
        }
    }
    
    private func ensureProperOrdering() {
        // Verificar que todos los sets tienen un order válido
        let sortedSets = performedExercise.sets.sorted(by: { $0.createdAt < $1.createdAt })
        for (idx, set) in sortedSets.enumerated() {
            set.order = idx
        }
        saveContext()
    }

    private func addSet() async {
        let exerciseSeed = defaultExercises.first(where: { $0.slug == performedExercise.slug })
        let exerciseType = exerciseSeed?.type ?? .reps
        
        let allSets = entrenamientos.flatMap { $0.ejercicios }.filter { $0.slug == performedExercise.slug }.flatMap { $0.sets }
        let perfilObjetivo = perfiles.first?.objetivo
        let nombreEjercicio = exerciseSeed?.name ?? performedExercise.slug
        let grupoMuscular = exerciseSeed.map { $0.group.localizedName } ?? ""
        let suggestedWeight = await suggestNextWeight(for: performedExercise, setsHistoricos: allSets, perfilObjetivo: perfilObjetivo, exerciseName: nombreEjercicio, exerciseGroup: grupoMuscular)

        let suggestedReps = await suggestNextReps(
            for: performedExercise,
            setsHistoricos: allSets,
            perfilObjetivo: perfilObjetivo,
            exerciseName: nombreEjercicio,
            exerciseGroup: grupoMuscular
        )

        let newOrder = (performedExercise.sets.map { $0.order }.max() ?? -1) + 1

        let newSet: ExerciseSet
        if exerciseType == .duration {
            newSet = ExerciseSet(reps: 0, weight: suggestedWeight, order: newOrder, performedExercise: performedExercise, createdAt: Date())
            newSet.duration = 60
        } else {
            newSet = ExerciseSet(reps: suggestedReps, weight: suggestedWeight, order: newOrder, performedExercise: performedExercise, createdAt: Date())
            newSet.duration = 0
        }
        newSet.id = UUID()
        context.insert(newSet)
        performedExercise.sets.append(newSet)
        
        // RENUMERAR order tras añadir set para garantizar orden visual coherente por 'order'
        let sorted = performedExercise.sets.sorted(by: { $0.createdAt < $1.createdAt })
        for (idx, set) in sorted.enumerated() {
            set.order = idx
        }
        
        saveContext()
        syncStringsWithModel()
        actualizarProgresoLiveActivity()
    }

    private func deleteSets(at offsets: IndexSet) {
        let sortedSets = performedExercise.sets.sorted(by: { $0.order < $1.order })
        let setsToRemove = offsets.map { sortedSets[$0] }
        for set in setsToRemove {
            if let index = performedExercise.sets.firstIndex(of: set) {
                performedExercise.sets.remove(at: index)
                context.delete(set)
            }
        }
        // Reenumerar los órdenes secuencialmente empezando desde 0 usando order
        let sorted = performedExercise.sets.sorted(by: { $0.order < $1.order })
        for (idx, set) in sorted.enumerated() {
            set.order = idx
        }
        saveContext()
        syncStringsWithModel()
        actualizarProgresoLiveActivity()
    }

    private func saveContext() {
        do {
            try context.save()
        } catch {
            print("❌ Error al guardar cambios en series: \(error)")
            context.rollback()
        }
    }
    
    private func formatPeso(_ peso: Double) -> String {
        if peso.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", peso)
        } else {
            return String(format: "%.1f", peso)
        }
    }
    
    private func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy"
        return formatter.string(from: date)
    }
    
    private func actualizarProgresoLiveActivity() {
        guard let entrenamiento = performedExercise.entrenamiento else { return }
        let progreso = entrenamiento.progresoEjercicios
        Task {
            await LiveActivityManager.shared.update(
                startedAt: entrenamiento.startDate ?? Date(),
                progress: progreso
            )
        }
    }
}

// Extension para acceso seguro a array indices sin causar crash
private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - ExerciseRowView auxiliar y helper estático

private struct ExerciseRowView: View {
    let pe: PerformedExercise
    let entrenamientos: [Entrenamiento]
    
    var body: some View {
        let resumen = resumenSetsStatic(for: pe)
        let allSets = entrenamientos.flatMap { $0.ejercicios }.filter { $0.slug == pe.slug }.flatMap { $0.sets }
        let historicMax = allSets.map { $0.weight }.max() ?? 0
        let hasHistoricMax = pe.sets.contains(where: { abs($0.weight - historicMax) < 0.0001 && historicMax > 0 })
        
        if let seed = defaultExercises.first(where: { $0.slug == pe.slug }) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(seed.name).font(.headline)
                    if hasHistoricMax {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                    }
                }
                Text(seed.desc).font(.caption).foregroundStyle(.secondary)
                if !resumen.isEmpty {
                    Text(resumen)
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(pe.slug)
                if !resumen.isEmpty {
                    Text(resumen)
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }
}

// Static helper para uso en struct auxiliar
private func resumenSetsStatic(for ejercicio: PerformedExercise) -> String {
    let sets = ejercicio.sets.sorted { $0.order < $1.order }
    guard !sets.isEmpty else { return "" }
    return sets.map { set in
        let reps = set.reps
        let peso = set.weight.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", set.weight) : String(format: "%.1f", set.weight)
        return "\(reps)x\(peso)kg"
    }.joined(separator: ", ")
}

