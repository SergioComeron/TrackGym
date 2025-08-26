//
//  EntrenamientoView.swift
//  TrackGym
//
//  Created by Sergio Comerón on 17/8/25.
//

import SwiftUI
import SwiftData
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
                    .accessibilityLabel(isGroupSectionExpanded ? "Ocultar grupos musculares" : "Mostrar grupos musculares")

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
                            if let seed = defaultExercises.first(where: { $0.slug == pe.slug }) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(seed.name).font(.headline)
                                    Text(seed.desc).font(.caption).foregroundStyle(.secondary)
                                }
                            } else {
                                Text(pe.slug) // Fallback si no existe en el catálogo
                            }
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
        .onAppear {
            print("🔍 OnAppear - Estado INICIAL:")
            for (i, ejercicio) in entrenamiento.ejercicios.enumerated() {
                print("  [\(i)] \(ejercicio.slug) - order: \(ejercicio.order) - id: \(ejercicio.id)")
            }
            
            // COMENTAR TEMPORALMENTE la migración para aislar el problema
             migrateLegacyExerciseOrderIfNeeded()
            
            print("🔍 OnAppear - Estado FINAL:")
            for (i, ejercicio) in entrenamiento.ejercicios.enumerated() {
                print("  [\(i)] \(ejercicio.slug) - order: \(ejercicio.order) - id: \(ejercicio.id)")
            }
        }
    }
    
    // MARK: - Computed property para ejercicios únicos
    private var uniqueEjercicios: [PerformedExercise] {
        let sorted = entrenamiento.ejercicios.sorted(by: { $0.order < $1.order })
        print("🔍 uniqueEjercicios - Ejercicios ordenados:")
        for (i, ejercicio) in sorted.enumerated() {
            print("  [\(i)] \(ejercicio.slug) - order: \(ejercicio.order)")
        }
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
        print("🔧 Iniciando movimiento agresivo...")
        
        var ejerciciosOrdenados = entrenamiento.ejercicios.sorted { $0.order < $1.order }
        ejerciciosOrdenados.move(fromOffsets: source, toOffset: destination)
        
        // Actualizar los values de 'order'
        for (idx, ejercicio) in ejerciciosOrdenados.enumerated() {
            ejercicio.order = idx
            print("🔧 Actualizando \(ejercicio.slug) order = \(idx)")
        }
        
        // 🔑 VERSIÓN AGRESIVA: Vaciar completamente y reconstruir
        let ejerciciosReordenados = ejerciciosOrdenados
        print("🔧 Vaciando array...")
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
        print("🔧 Reconstruyendo array en orden correcto...")
        entrenamiento.ejercicios = ejerciciosReordenados
        
        // Segundo guardado (array reordenado)
        do {
            try context.save()
            print("✅ Array reconstruido y guardado")
            
            // Verificación final
            print("🔍 Verificación post-reconstrucción:")
            for (i, ejercicio) in entrenamiento.ejercicios.enumerated() {
                print("  [\(i)] \(ejercicio.slug) - order: \(ejercicio.order)")
            }
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
        
        print("🔧 Migrando orden legacy...")
        
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

    @Query(sort: [SortDescriptor(\Entrenamiento.startDate, order: .reverse)])
    private var entrenamientos: [Entrenamiento]

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
        let anteriorSets: [ExerciseSet] = anterior?.ejercicios.filter { $0.slug == performedExercise.slug }.flatMap { $0.sets.sorted { $0.order < $1.order } } ?? []

        // Nuevo: determinar si es editable (tiene startDate y no está finalizado)
        let isEditable = performedExercise.entrenamiento?.startDate != nil && !isFinished
        
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
                        ForEach(anteriorSets, id: \.id) { set in
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !isFinished && (performedExercise.entrenamiento?.startDate != nil) {
                    Button("Añadir serie") {
                        addSet()
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

    private func addSet() {
        let newOrder = (performedExercise.sets.map { $0.order }.max() ?? -1) + 1
        let exerciseSeed = defaultExercises.first(where: { $0.slug == performedExercise.slug })
        let exerciseType = exerciseSeed?.type ?? .reps
        
        let newSet: ExerciseSet
        if exerciseType == .duration {
            newSet = ExerciseSet(reps: 0, weight: 0, order: newOrder, performedExercise: performedExercise, createdAt: Date())
            newSet.duration = 60
        } else {
            newSet = ExerciseSet(reps: 15, weight: 50, order: newOrder, performedExercise: performedExercise, createdAt: Date())
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
