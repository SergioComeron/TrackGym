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
    @State private var isGeneratingAISummary = false
    @State private var isShowingGroupEditor = false

    private var isFinished: Bool { entrenamiento.endDate != nil }

    @Query(sort: [SortDescriptor(\Entrenamiento.startDate, order: .reverse)])
    private var entrenamientos: [Entrenamiento]
    
    @Query
    private var perfiles: [Perfil]

    var body: some View {
        Form {
            // Encabezado compacto con estado e inicio/fin (no en secciones)
            VStack(alignment: .leading, spacing: 8) {
                if let end = entrenamiento.endDate, let start = entrenamiento.startDate {
                    Label {
                        Text("Terminado el \(DateFormatter.cachedDateTime.string(from: end))")
                    } icon: {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Text("Inicio: \(DateFormatter.cachedDateTime.string(from: start))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let start = entrenamiento.startDate {
                    Label {
                        Text("En curso desde \(DateFormatter.cachedDateTime.string(from: start))")
                    } icon: {
                        Image(systemName: "record.circle.fill").foregroundStyle(.red)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                } else {
                    Label {
                        Text("Sin inicio")
                    } icon: {
                        Image(systemName: "clock").foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                // Acciones (no dentro de secciones)
                HStack(spacing: 12) {
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
                            HStack(spacing: 6) {
                                Text("Empezar")
                                Image(systemName: "play.fill")
                            }
                        }
                        .buttonStyle(.plain)

                    } else if entrenamiento.endDate == nil {
                        Button(role: .destructive) {
                            Task {
                                entrenamiento.endDate = Date()
                                cleanupDuplicates()
                                try? context.save()

                                isGeneratingAISummary = true
                                defer { isGeneratingAISummary = false }
                                if let resumen = await generarResumenEntrenoAI(para: entrenamiento) {
                                    entrenamiento.aiSummary = resumen
                                    try? context.save()

                                    let preview = flattenAISummary(resumen)
                                    print("""
                                    \n🧠 IA PLAIN (Preview de render)
                                    --------------------------------
                                    \(preview)
                                    --------------------------------
                                    """)
                                }
                                await LiveActivityManager.shared.end()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text("Terminar")
                                Image(systemName: "stop.circle")
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 6)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))

            // CTA cuando no hay grupos seleccionados
            if entrenamiento.gruposMusculares.isEmpty {
                HStack {
                    Button {
                        isShowingGroupEditor = true
                    } label: {
                        HStack(spacing: 6) {
                            Text("Añadir grupos musculares")
                            Image(systemName: "square.grid.2x2")
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
            }

            // Grupos musculares como píldoras (solo los trabajados)
            if !entrenamiento.gruposMusculares.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Grupos musculares")
                        .font(.headline)
                    let selected = Array(Set(entrenamiento.gruposMusculares)).sorted { $0.localizedName < $1.localizedName }
                    let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                        ForEach(selected, id: \.self) { grupo in
                            Text(grupo.localizedName)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(Color.accentColor.opacity(0.15))
                                )
                                .overlay(
                                    Capsule().stroke(Color.accentColor, lineWidth: 1)
                                )
                                .foregroundStyle(.primary)
                                .accessibilityLabel("Grupo muscular: \(grupo.localizedName)")
                        }
                    }
                    HStack {
                        Button {
                            isShowingGroupEditor = true
                        } label: {
                            HStack(spacing: 6) {
                                Text("Editar grupos")
                                Image(systemName: "slider.horizontal.3")
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 6)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
            }

            // Resumen IA (sección ligera solo para este bloque)
            Section {
                if isGeneratingAISummary {
                    AIActivityIndicator()
                        .padding(.vertical, 4)
                } else if let raw = entrenamiento.aiSummary, !raw.isEmpty {
                    let plain = flattenAISummary(raw)
                    Text(plain)
                        .font(.callout)
                        .textSelection(.enabled)
                        .lineSpacing(0)
                        .contextMenu {
                            Button {
                                regenerateAISummary()
                            } label: {
                                Label("Regenerar resumen (IA)", systemImage: "arrow.clockwise")
                            }
                        }
                } else {
                    Text("Aún no hay resumen. Pulsa \"Terminar\" para generarlo.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Resumen (IA)")
                    .onTapGesture(count: 5) { regenerateAISummary() }
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
        .sheet(isPresented: $isShowingGroupEditor) {
            GroupSelectorSheet(entrenamiento: entrenamiento) {
                try? context.save()
            }
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
        let ejercicios = entrenamiento.ejercicios ?? []
        return ejercicios.sorted { $0.order < $1.order }
    }
    
    /// Convierte la salida del modelo a un único párrafo sin Markdown ni listas
    private func flattenAISummary(_ text: String) -> String {
        var s = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        // Quitar negritas/itálicas Markdown
        s = s.replacingOccurrences(of: "**", with: "")
        s = s.replacingOccurrences(of: "__", with: "")
        s = s.replacingOccurrences(of: "*", with: "")
        s = s.replacingOccurrences(of: "_", with: "")
        // Quitar bullets al inicio de línea
        s = regexReplace(s, pattern: #"(?m)^\s*[-•·\*]\s+"#, replacement: "")
        // Colapsar saltos de línea y espacios múltiples a un solo espacio
        s = regexReplace(s, pattern: #"\s+"#, replacement: " ")
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
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
        guard let ejercicios = entrenamiento.ejercicios else {
            return []
        }
        let existingSlugs = Set(ejercicios.map { $0.slug })
        return defaultExercises.filter { exercise in
            selectedGroups.contains(exercise.group) && !existingSlugs.contains(exercise.slug)
        }
    }

    private func addExerciseSafely(slug: String) {
        guard !isFinished else { return }
        
        // Doble verificación más robusta
        let existingExercise = (entrenamiento.ejercicios ?? []).first { $0.slug == slug }
        guard existingExercise == nil else {
            print("⚠️ Ejercicio \(slug) ya existe, evitando duplicado")
            return
        }
        
        // Crear con ID único para CloudKit
        let pe = PerformedExercise(slug: slug, entrenamiento: entrenamiento)
        pe.id = UUID()
        pe.order = ((entrenamiento.ejercicios ?? []).map { $0.order }.max() ?? -1) + 1

        context.insert(pe)
        if entrenamiento.ejercicios == nil { entrenamiento.ejercicios = [] }
        entrenamiento.ejercicios?.append(pe)
        
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
        var current = entrenamiento.ejercicios ?? []
        let toRemove = offsets.compactMap { current[safe: $0] }

        for pe in toRemove {
            context.delete(pe)
        }

        current.remove(atOffsets: offsets)
        entrenamiento.ejercicios = current

        // Reenumerar los órdenes después de borrar para mantener el orden
        let reOrdered = (entrenamiento.ejercicios ?? []).sorted { $0.order < $1.order }
        for (idx, ejercicio) in reOrdered.enumerated() {
            ejercicio.order = idx
        }
        entrenamiento.ejercicios = reOrdered

        do {
            try context.save()
        } catch {
            print("❌ Error al eliminar ejercicios: \(error)")
            context.rollback()
        }
    }

    private func movePerformedExercises(from source: IndexSet, to destination: Int) {
        var ejerciciosOrdenados = (entrenamiento.ejercicios ?? []).sorted { $0.order < $1.order }
        ejerciciosOrdenados.move(fromOffsets: source, toOffset: destination)

        // Actualizar los values de 'order'
        for (idx, ejercicio) in ejerciciosOrdenados.enumerated() {
            ejercicio.order = idx
        }

        // Vaciar y reconstruir de forma segura
        entrenamiento.ejercicios = []
        do {
            try context.save()
            entrenamiento.ejercicios = ejerciciosOrdenados
            try context.save()
        } catch {
            print("❌ Error al guardar reconstrucción: \(error)")
            context.rollback()
        }
    }
    
    private func cleanupDuplicates() {
        let current = entrenamiento.ejercicios ?? []
        let slugGroups = Dictionary(grouping: current) { $0.slug }
        var exercisesToDelete: [PerformedExercise] = []

        for (slug, exercises) in slugGroups where exercises.count > 1 {
            print("🔧 Encontrados \(exercises.count) duplicados para \(slug)")
            // Mantener el más reciente
            let sortedExercises = exercises.sorted { $0.createdAt > $1.createdAt }
            exercisesToDelete.append(contentsOf: Array(sortedExercises.dropFirst()))
        }

        if !exercisesToDelete.isEmpty {
            var updated = current
            for exercise in exercisesToDelete {
                if let index = updated.firstIndex(of: exercise) {
                    updated.remove(at: index)
                }
                context.delete(exercise)
            }
            entrenamiento.ejercicios = updated
            print("🗑️ Eliminados \(exercisesToDelete.count) ejercicios duplicados")
            do {
                try context.save()
            } catch {
                print("❌ Error guardando tras cleanupDuplicates: \(error)")
                context.rollback()
            }
        }
    }
    
    private func cleanupDuplicatesInMemory() {
        let current = entrenamiento.ejercicios ?? []
        var unique: [String: PerformedExercise] = [:]
        for e in current {
            if unique[e.slug] == nil {
                unique[e.slug] = e
            }
        }
        let uniqArr = Array(unique.values)
        if uniqArr.count != current.count {
            entrenamiento.ejercicios = uniqArr
            do {
                try context.save()
            } catch {
                print("❌ Error guardando tras cleanupDuplicatesInMemory: \(error)")
                context.rollback()
            }
        }
    }
    
    /// Genera el resumen del entrenamiento con Apple Intelligence y lo devuelve.
    private func generarResumenEntrenoAI(para entreno: Entrenamiento) async -> String? {
        // Perfil (opcional)
        var perfilStr = ""
        if let p = perfiles.first {
            var restriccionesStr = ""
            if let r = p.restricciones, !r.isEmpty { restriccionesStr = ", Restricciones: \(r)" }
            perfilStr = "Perfil: Edad \(p.edad), Peso \(Int(p.peso)) kg, Altura \(Int(p.altura)) cm, Sexo \(p.sexo), Objetivo: \(p.objetivo), Nivel actividad: \(p.nivelActividad)\(restriccionesStr)\n"
        }

        // Grupos y ejercicios
        let grupos = entreno.gruposMusculares.map { $0.localizedName }.joined(separator: ", ")

        let ejerciciosStr = (entreno.ejercicios ?? [])
            .sorted { $0.order < $1.order }
            .map { ejercicio -> String in
                let seed = defaultExercises.first(where: { $0.slug == ejercicio.slug })
                let setsText = (ejercicio.sets ?? [])
                    .sorted { $0.order < $1.order }
                    .map { set -> String in
                        if let seed {
                            switch seed.type {
                            case .duration: return "\(Int(set.duration))seg@\(String(format: "%.1f", set.weight))kg"
                            case .reps:     return "\(set.reps)x\(String(format: "%.1f", set.weight))kg"
                            }
                        }
                        return "\(set.reps)x\(String(format: "%.1f", set.weight))kg"
                    }
                    .joined(separator: ", ")
                let name = seed?.name
                    ?? ejercicio.slug
                        .replacingOccurrences(of: "-", with: " ")
                        .replacingOccurrences(of: "_", with: " ")
                        .capitalized
                return "\(name): \(setsText)"
            }
            .joined(separator: "\n")


        let prompt = """
        \(perfilStr)Eres un entrenador personal experto en hipertrofia. Analiza SOLO este entrenamiento terminado.
        DATOS:
        - Grupos trabajados: \(grupos)
        - Ejercicios (serie x peso o seg):
        \(ejerciciosStr)

        OBJETIVO: decirme si el entreno es adecuado para el/los grupo(s) considerando series, reps y pesos; y darme 1–2 recomendaciones prácticas.

        FORMATO DE SALIDA (OBLIGATORIO):
        - Un único párrafo, estilo conversación de tú a tú.
        - Sin encabezados, sin listas, sin saltos de línea, sin Markdown, sin comillas.
        - Máx. 3 frases cortas, separadas por punto y coma o punto.
        - Incluye un veredicto breve (Correcto o Mejorable), 1–2 aciertos y 1–2 ajustes.
        - No repitas los datos de entrada.
        """

        let instrucciones = """
        Eres un entrenador conciso. Responde SOLO con un párrafo sin formato ni saltos de línea.
        Prohibido Markdown, asteriscos, guiones y títulos. Usa frases breves y directas.
        Máximo ~300 caracteres. Evita relleno. No repitas datos del prompt.
        """

        do {
            let session = LanguageModelSession(instructions: instrucciones)
            let respuesta = try await session.respond(to: prompt)
            let raw = respuesta.content
            print("""
            
            🧠 IA RAW (Resumen Entreno)
            ---------------------------
            \(raw)
            ---------------------------
            """)
            return raw
        } catch {
            print("❌ Error generando resumen IA: \(error)")
            return nil
        }
    }
    
    /// Regenera el resumen IA (easter egg: 5 taps en el header o long press context menu)
    private func regenerateAISummary() {
        Task {
            guard entrenamiento.endDate != nil else { return } // solo si está terminado
            isGeneratingAISummary = true
            defer { isGeneratingAISummary = false }
            if let resumen = await generarResumenEntrenoAI(para: entrenamiento) {
                entrenamiento.aiSummary = resumen
                try? context.save()

                let preview = flattenAISummary(resumen)
                print("""
                🧠 IA PLAIN (Preview de render)
                --------------------------------
                \(preview)
                --------------------------------
                """)
            }
        }
    }

    /// Migra ejercicios antiguos asignándoles un 'order' secuencial según la fecha de creación si el campo no está bien definido.
    private func migrateLegacyExerciseOrderIfNeeded() {
        let ejercicios = entrenamiento.ejercicios ?? []

        // Solo migrar si realmente hay un problema
        let hasInvalidOrder = ejercicios.isEmpty ||
                             Set(ejercicios.map { $0.order }).count != ejercicios.count ||
                             ejercicios.allSatisfy { $0.order == 0 }

        guard hasInvalidOrder else {
            print("✅ Orden ya es válido, no se necesita migración")
            return
        }

        // Ordenar por fecha de creación y asignar order
        let sorted = ejercicios.sorted { $0.createdAt < $1.createdAt }
        for (idx, ejercicio) in sorted.enumerated() {
            ejercicio.order = idx
        }

        // Usar el mismo método agresivo para persistir
        entrenamiento.ejercicios = []
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
    let setIndex = performedExercise.sets?.count ?? 0
    let minA = minAllowed
    var maxA = maxAllowed
    if setIndex >= 3 { maxA = max(minA, maxA - 1) }

    let nombre = exerciseName ?? performedExercise.slug
    let grupo = exerciseGroup != nil ? " (grupo: \(exerciseGroup!))" : ""
    let recentReps = setsHistoricos.suffix(5).map { $0.reps }
    let summary = recentReps.isEmpty ? "sin historial" : recentReps.map(String.init).joined(separator: ", ")

    let prompt = """
    TAREA: Proponer SOLO un número entero de repeticiones para la PRÓXIMA SERIE.
    CONTEXTO:
    - Ejercicio: \(nombre)\(grupo)
    - Histórico (reps recientes): [\(summary)]  // solo información, no formatees
    - Objetivo: \(perfilObjetivo ?? "Ganar músculo") → rango objetivo: \(baseRange.0)–\(baseRange.1) reps
    - Serie actual (nº): \(setIndex + 1)

    REGLAS DURAS (OBLIGATORIAS):
    1) PRINCIPIO DE PROGRESIÓN: si en la última sesión o en esta misma llevabas **el mismo peso** y alcanzaste el techo del rango (≥ \(baseRange.1) reps), incrementa reps en +1 (siempre dentro del rango permitido) o, si ya estás en el techo, mantén reps y sugiere subir peso (pero IGUAL devuelve reps dentro del rango permitido).
    2) Si la última serie estuvo **por debajo** del rango (≤ \(baseRange.0)−1), baja reps en −1 (mínimo \(baseRange.0)).
    3) Si estuvo **dentro** del rango, **mantén**.
    4) RANGO PERMITIDO PARA ESTA PROPUESTA: min=\(minA), max=\(maxA) reps.
    5) PASO MÁXIMO respecto a la última serie: ±\(stepCap) reps.

    FORMATO DE RESPUESTA: escribe **solo** un número entero (ej. 12). Sin texto extra.
    """

    let instrucciones = """
    Eres un entrenador de fuerza/hipertrofia. Devuelves **solo un número entero** (reps).
    Sigue las REGLAS DURAS literalmente; si hay conflicto, prioriza el RANGO PERMITIDO y el PASO MÁXIMO.
    Si detectas que se alcanzó el techo del rango con el mismo peso en la última referencia, empuja a progresar: +1 rep si cabe; si no cabe, mantén reps (y deja implícito que habrá que subir peso en la siguiente serie, pero NO lo escribas).
    Prohibido texto adicional o unidades.
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
    let currentSetsSorted = performedExercise.setsOrEmpty.sorted { $0.order < $1.order }
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
    let setIndex = performedExercise.setsOrEmpty.count
    let prompt = """
    TAREA: Proponer SOLO un número en kg (1 decimal) para la PRÓXIMA SERIE.
    CONTEXTO:
    - Ejercicio: \(nombre)\(grupo)
    - Histórico (kg recientes): [\(summary)]  // más reciente al final
    - Reps última serie actual: \(currentSetsSorted.last?.reps ?? reps)
    - Objetivo: \(objetivo) → rango objetivo de reps: \(repRange.0)–\(repRange.1)
    - Serie actual (nº): \(setIndex + 1)

    REGLAS DURAS (OBLIGATORIAS):
    1) PROGRESIÓN (hipertrofia): Si con el **mismo peso** alcanzaste el **techo del rango** (≥ \(repRange.1) reps) en la última referencia válida (histórico o serie previa), **sube el peso** ligeramente.
    2) Si quedaste **por debajo** del rango (≤ \(repRange.0)−1), **baja** ligeramente el peso.
    3) Si quedaste **dentro** del rango, **mantén** o micro-ajusta.
    4) RANGO PERMITIDO (kg): min=\(String(format: "%.1f", minAllowed)), max=\(String(format: "%.1f", maxAllowed)).
    5) SUGERENCIA BASE: \(String(format: "%.1f", proposedClamped)) kg (puedes modificarla si lo exigen las reglas 1–3).
    6) PASO MÁXIMO vs el último peso usado: ±10% y nunca más de \(String(format: "%.1f", inc)).

    FORMATO DE RESPUESTA: escribe **solo** un número con 1 decimal (ej. 37.5). Sin texto extra.
    """

    let instrucciones = """
    Eres un entrenador de fuerza/hipertrofia. Devuelves **solo un número** con 1 decimal.
    Aplica estrictamente las reglas de PROGRESIÓN y el RANGO PERMITIDO. Si la última referencia alcanzó el techo del rango con el mismo peso, prioriza subir ligeramente el peso (sin salirte del rango y del paso máximo). Si estuvo por debajo, reduce; si estuvo dentro, mantén.
    No añadas texto, símbolos ni unidades.
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


extension PerformedExercise {
    /// Devuelve siempre un array (vacío si `sets` es nil)
    var setsOrEmpty: [ExerciseSet] {
        sets ?? []
    }
}

// Custom AI spinner indicator for summaries
private struct AIActivityIndicator: View {
    @State private var spin = false
    var text: String = "Generando resumen…"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "apple.intelligence")
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.accentColor, Color.accentColor.opacity(0.45))
                .font(.title3)
                .symbolEffect(.rotate, options: .repeating, value: spin)
                .symbolEffect(.variableColor, options: .repeating, value: spin)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear { spin = true }
    }
}

private struct GroupSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var entrenamiento: Entrenamiento
    var onSave: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(GrupoMuscular.allCases, id: \.self) { grupo in
                        let isOn = entrenamiento.gruposMusculares.contains(grupo)
                        Button {
                            toggle(grupo)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                Text(grupo.localizedName)
                                    .lineLimit(1)
                            }
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isOn ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isOn ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: 1)
                            )
                            .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Grupos musculares")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") {
                        onSave()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func toggle(_ grupo: GrupoMuscular) {
        if let idx = entrenamiento.gruposMusculares.firstIndex(of: grupo) {
            entrenamiento.gruposMusculares.remove(at: idx)
        } else {
            entrenamiento.gruposMusculares.append(grupo)
        }
        try? context.save()
    }
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
    
    
    
    
    // MARK: - Precomputed data to keep `body` simple (avoid heavy type-checking)
    private var exerciseSeed: ExerciseSeed? {
        defaultExercises.first { $0.slug == performedExercise.slug }
    }
    private var exerciseType: ExerciseType { exerciseSeed?.type ?? .reps }

    private var allEjercicios: [PerformedExercise] {
        let arrays = entrenamientos.compactMap { $0.ejercicios }
        return arrays.flatMap { $0 }
    }
    private var ejerciciosMismoSlug: [PerformedExercise] {
        allEjercicios.filter { $0.slug == performedExercise.slug }
    }
    private var setsHistoricos: [ExerciseSet] {
        let arrays = ejerciciosMismoSlug.map { $0.setsOrEmpty }
        return arrays.flatMap { $0 }
    }
    private var setMax: ExerciseSet? {
        setsHistoricos.max(by: { $0.weight < $1.weight })
    }
    private var entrenoMax: Entrenamiento? {
        guard let pe = setMax?.performedExercise else { return nil }
        return entrenamientos.first { ($0.ejercicios ?? []).contains(pe) }
    }
    private var fechaMax: Date? { entrenoMax?.startDate }

    private var entrenamientosAnteriores: [Entrenamiento] {
        entrenamientos
            .filter { ($0.ejercicios ?? []).contains(where: { $0.slug == performedExercise.slug }) && $0 != performedExercise.entrenamiento }
            .sorted { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }
    }
    private var anterior: Entrenamiento? { entrenamientosAnteriores.first }
    private var fechaAnt: Date? { anterior?.startDate }
    private var anteriorSets: [ExerciseSet] {
        let ejercicios = anterior?.ejercicios?.filter { $0.slug == performedExercise.slug } ?? []
        let arrays = ejercicios.map { $0.setsOrEmpty.sorted { $0.createdAt < $1.createdAt } }
        return arrays.flatMap { $0 }
    }

    private var isEditable: Bool {
        performedExercise.entrenamiento?.startDate != nil && !isFinished
    }
    
    
    
    
    

    var body: some View {
        
//        let exerciseSeed = defaultExercises.first(where: { $0.slug == performedExercise.slug })
//        let exerciseType = exerciseSeed?.type ?? .reps
//        
//        let ejercicios: [PerformedExercise] = entrenamientos
//            .compactMap { $0.ejercicios }
//            .flatMap { $0 }
//
//        let ejerciciosMismoSlug = ejercicios.filter { $0.slug == performedExercise.slug } // o `pe.slug`
//        let setsHistoricos: [ExerciseSet] = ejerciciosMismoSlug.flatMap { $0.setsOrEmpty }
//        
//        // Nueva declaración simplificada fuera del VStack header
//        let setMax = setsHistoricos.max(by: { $0.weight < $1.weight })
//        let peMax = setMax?.performedExercise
//        let entrenoMax = peMax.flatMap { pe in entrenamientos.first(where: { ($0.ejercicios ?? []).contains(pe) }) }
//        let fechaMax = entrenoMax?.startDate
//        let entrenamientosAnteriores = entrenamientos
//            .filter { ($0.ejercicios ?? []).contains(where: { $0.slug == performedExercise.slug }) && $0 != performedExercise.entrenamiento }
//            .sorted { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }
//        let anterior = entrenamientosAnteriores.first
//        let fechaAnt = anterior?.startDate
//        // Ordenar las series de la última sesión previa por fecha (createdAt) ascendente
//        let anteriorSets: [ExerciseSet] = (anterior?
//            .ejercicios?
//            .filter { $0.slug == performedExercise.slug }
//            .flatMap { $0.setsOrEmpty.sorted { $0.createdAt < $1.createdAt } }) ?? []
//        
//        // Nuevo: determinar si es editable (tiene startDate y no está finalizado)
//        let isEditable = performedExercise.entrenamiento?.startDate != nil && !isFinished
        
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
                    let sortedSets = performedExercise.setsOrEmpty.sorted(by: { $0.order < $1.order })
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
                                    let sortedSets = performedExercise.setsOrEmpty.sorted(by: { $0.order < $1.order })
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
                                    let sortedSets = performedExercise.setsOrEmpty.sorted(by: { $0.order < $1.order })
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
                                    let sortedSets = performedExercise.setsOrEmpty.sorted(by: { $0.order < $1.order })
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
                                    let sortedSets = performedExercise.setsOrEmpty.sorted(by: { $0.order < $1.order })
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
                        AIActivityIndicator(text: "Calculando sugerencia…")
                            .padding(.vertical, 4)
                    }
                }
#if canImport(Charts)
                Section {
                    let currentSets = performedExercise.setsOrEmpty.sorted { $0.order < $1.order }
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
        let allSets: [ExerciseSet] = entrenamientos
            .compactMap { $0.ejercicios }
            .flatMap { $0 }
            .filter { $0.slug == performedExercise.slug }
            .flatMap { $0.setsOrEmpty }     // 👈 usa helper para evitar opcionales
            .sorted { $0.createdAt > $1.createdAt }
        return allSets.first
    }
    
    // Función auxiliar para repetir la última serie copiada
    private func repeatLastSet(lastSet: ExerciseSet) {
        let newOrder = (performedExercise.setsOrEmpty.map { $0.order }.max() ?? -1) + 1
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
        if performedExercise.sets == nil {
            performedExercise.sets = []
        }
        performedExercise.sets?.append(newSet)        // RENUMERAR order por coherencia visual
        let sorted = performedExercise.setsOrEmpty.sorted(by: { $0.createdAt < $1.createdAt })
        for (idx, set) in sorted.enumerated() { set.order = idx }
        saveContext()
        syncStringsWithModel()
        actualizarProgresoLiveActivity()
    }

    // Sincroniza los arrays de String con los valores actuales del modelo
    // Se usa el array ordenado por 'order' ascendente para reflejar correctamente Serie 1 arriba, Serie N abajo
    private func syncStringsWithModel() {
        let sortedSets = performedExercise.setsOrEmpty.sorted(by: { $0.order < $1.order })
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
        let sortedSets = performedExercise.setsOrEmpty.sorted(by: { $0.createdAt < $1.createdAt })
        for (idx, set) in sortedSets.enumerated() {
            set.order = idx
        }
        saveContext()
    }

    private func addSet() async {
        let exerciseSeed = defaultExercises.first(where: { $0.slug == performedExercise.slug })
        let exerciseType = exerciseSeed?.type ?? .reps
        
        let allSets: [ExerciseSet] = entrenamientos
            .compactMap { $0.ejercicios }
            .flatMap { $0 }
            .filter { $0.slug == performedExercise.slug }
            .flatMap { $0.setsOrEmpty }
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

        let newOrder = (performedExercise.setsOrEmpty.map { $0.order }.max() ?? -1) + 1

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
        if performedExercise.sets == nil {
            performedExercise.sets = []
        }
        performedExercise.sets?.append(newSet)
        // RENUMERAR order tras añadir set para garantizar orden visual coherente por 'order'
        let sorted = performedExercise.setsOrEmpty.sorted(by: { $0.createdAt < $1.createdAt })
        for (idx, set) in sorted.enumerated() {
            set.order = idx
        }
        
        saveContext()
        syncStringsWithModel()
        actualizarProgresoLiveActivity()
    }

    private func deleteSets(at offsets: IndexSet) {
        // 1) Copia ordenada segura
        var current = performedExercise.setsOrEmpty.sorted { $0.order < $1.order }

        // 2) Asegura índices válidos y elimina en orden descendente
        let valid = offsets.filter { $0 < current.count }.sorted(by: >)
        let setsToRemove = valid.map { current[$0] }
        for idx in valid {
            current.remove(at: idx)
        }

        // 3) Borra de SwiftData los objetos eliminados
        for set in setsToRemove {
            context.delete(set)
        }

        // 4) Reenumera `order`
        for (i, set) in current.enumerated() {
            set.order = i
        }

        // 5) Reasigna al modelo (opcional) y guarda
        performedExercise.sets = current
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
        let allSets: [ExerciseSet] = entrenamientos
            .compactMap { $0.ejercicios }
            .flatMap { $0 }
            .filter { $0.slug == pe.slug }
            .flatMap { $0.setsOrEmpty }
            .sorted { $0.createdAt > $1.createdAt }
        let historicMax = allSets.map { $0.weight }.max() ?? 0
        let hasHistoricMax = pe.setsOrEmpty.contains(where: { abs($0.weight - historicMax) < 0.0001 && historicMax > 0 })
        
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
    let sets = ejercicio.setsOrEmpty.sorted { $0.order < $1.order }
    guard !sets.isEmpty else { return "" }
    return sets.map { set in
        let reps = set.reps
        let peso = set.weight.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", set.weight) : String(format: "%.1f", set.weight)
        return "\(reps)x\(peso)kg"
    }.joined(separator: ", ")
}


    /// Arregla casos donde la IA deja un par de asteriscos sin cerrar para negritas
    private func sanitizeUnclosedBold(in text: String) -> String {
        // Arreglar por párrafos para no arrastrar negritas a todo el documento
        let paragraphs = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n\n")
        let fixed = paragraphs.map { p -> String in
            let count = p.components(separatedBy: "**").count - 1
            if count % 2 != 0 { return p + "**" } // cerrar dentro del párrafo
            return p
        }
        return fixed.joined(separator: "\n\n")
    }

    /// Normaliza el Markdown para mejorar la presentación: cierra negritas sueltas, inserta saltos de párrafo razonables.
    private func normalizeMarkdownForDisplay(_ text: String) -> String {
        var md = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        // 1) Forzar salto de párrafo antes de secciones en negrita que vienen pegadas al punto

        // 2) Asegurar un salto de párrafo antes de items de lista que empiezan por '* '
        md = regexReplace(md, pattern: #"(?<!\n\n)\n\*\s"#, replacement: "\n\n* ")

        // 2b) Normalizar bullets: convertir "* " a "- " al inicio de línea
        md = regexReplace(md, pattern: #"(?m)^\*\s"#, replacement: "- ")

        // 2c) Asegurar salto de párrafo antes de items de lista que empiezan por '- '
        md = regexReplace(md, pattern: #"(?<!\n\n)\n-\s"#, replacement: "\n\n- ")

        // 2d) Limpiar bullets duplicados del modelo ("- - texto" o "- - - texto") → "- texto"
        md = regexReplace(md, pattern: #"(?m)^-\s+-\s+-\s+"#, replacement: "- ")
        md = regexReplace(md, pattern: #"(?m)^-\s+-\s+"#, replacement: "- ")

        // 2e) Eliminar líneas sueltas que solo contienen "**"
        md = regexReplace(md, pattern: #"(?m)^\s*\*\*\s*$"#, replacement: "")

        // 3) Convertir saltos simples en dobles (párrafo) cuando no haya ya uno doble
        md = regexReplace(md, pattern: #"(?<!\n)\n(?!\n)"#, replacement: "\n\n")

        // 4) Evitar triples saltos
        md = md.replacingOccurrences(of: "\n\n\n", with: "\n\n")

        // 5) Titulares tipo "Palabra: " al inicio de línea → envolver en ** ** si no lo están
        // Evita duplicar si ya tiene ** al principio
        md = regexReplace(md, pattern: #"(?m)^(\s*)(?!\*\*)([A-ZÁÉÍÓÚ][^\n:]{2,60}):\s"#, replacement: "$1**$2:** ")

        return md
    }

    /// Utilidad de reemplazo regex segura
    private func regexReplace(_ source: String, pattern: String, replacement: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return source }
        let range = NSRange(source.startIndex..., in: source)
        return re.stringByReplacingMatches(in: source, options: [], range: range, withTemplate: replacement)
    }

    /// Formatea el resumen IA al esquema Markdown esperado
    private func formatAISummaryForDisplay(_ text: String) -> String {
        var md = normalizeMarkdownForDisplay(text)

        // Si los encabezados aparecen pegados al texto y SIN negrita, separarlos y poner en negrita (solo al inicio de línea, sin crear líneas con solo '**')
        md = regexReplace(md, pattern: #"(?m)^(?!\*\*)\s*(Veredicto|Puntos fuertes|Ajustes recomendados|Aspectos a vigilar):\s*"#, replacement: "**$1:**\n\n")

        // Asegurar encabezados en líneas separadas (si vienen pegados al texto)
        md = regexReplace(md, pattern: #"(?<!\n\n)\*\*(Puntos fuertes|Ajustes recomendados|Aspectos a vigilar):\*\*"#, replacement: "\n\n**$1:**")

        // Forzar salto doble después de la línea de Veredicto
        md = regexReplace(md, pattern: #"\*\*Veredicto:\*\*\s*([^\n]+)"#, replacement: "**Veredicto:** $1\n\n")

        // Convertir contenido plano en bullets si no lo es ya
        md = ensureBullets(in: md, heading: "Puntos fuertes", maxItems: 3)
        md = ensureBullets(in: md, heading: "Ajustes recomendados", maxItems: 3)
        md = ensureBullets(in: md, heading: "Aspectos a vigilar", maxItems: 2)

        // Limpieza de saltos extra
        md = md.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        return md
    }

    /// Garantiza que el cuerpo bajo un encabezado esté en bullets '- '
    private func ensureBullets(in source: String, heading: String, maxItems: Int) -> String {
        let escapedHeading = NSRegularExpression.escapedPattern(for: heading)
        let pattern = #"(?s)(\*\*#HEADING:\*\*)\s*(.*?)(?=\n\n\*\*|\z)"#.replacingOccurrences(of: "#HEADING", with: escapedHeading)
        guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return source }
        let ns = source as NSString
        var result = source
        let matches = re.matches(in: source, options: [], range: NSRange(location: 0, length: ns.length))
        for m in matches.reversed() {
            let headerRange = m.range(at: 1)
            let bodyRange = m.range(at: 2)
            let header = ns.substring(with: headerRange)
            let bodyRaw = ns.substring(with: bodyRange).trimmingCharacters(in: .whitespacesAndNewlines)

            // Si ya tiene bullets, no tocar (tolerar espacios/saltos antes del guion)
            if bodyRaw.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("- ") { continue }

            // Partir por puntos, punto y coma o saltos simples
            let pieces = bodyRaw
                .replacingOccurrences(of: "•", with: ". ")
                .replacingOccurrences(of: "·", with: ". ")
                .split(whereSeparator: { ".;\n".contains($0) })
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if pieces.isEmpty { continue }
            let items = Array(pieces.prefix(maxItems))
            let bullets = items.map { "- \($0)" }.joined(separator: "\n")
            let replacement = "\(header)\n\n\(bullets)\n\n"

            let fullRange = NSRange(location: headerRange.location, length: (bodyRange.location + bodyRange.length) - headerRange.location)
            if let r = Range(fullRange, in: result) {
                result.replaceSubrange(r, with: replacement)
            }
        }
        return result
    }
