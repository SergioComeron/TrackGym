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
    @State private var isShowingExercisePicker = false
    @State private var isGroupSectionExpanded = false
    @State private var selectedExercise: PerformedExercise?

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
                        Text(entrenamiento.gruposUnicos
                            .map { $0.localizedName }
                            .joined(separator: " · "))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Section {
                    if isGroupSectionExpanded {
                        ForEach(GrupoMuscular.allCases, id: \.self) { grupo in
                            Toggle(grupo.localizedName, isOn: binding(for: grupo))
                        }
                    }
                } header: {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isGroupSectionExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Text("Grupos trabajados")
                            Spacer()
                            Image(systemName: isGroupSectionExpanded ? "chevron.down" : "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
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
                if let end = entrenamiento.endDate {
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
                Button("OK") {
                    cleanupDuplicates()
                    try? context.save()
                    dismiss()
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
            // Limpieza al cargar la vista (útil después de sincronización)
            cleanupDuplicates()
        }
    }
    
    // MARK: - Computed property para ejercicios únicos
    private var uniqueEjercicios: [PerformedExercise] {
        cleanupDuplicatesInMemory()
        return entrenamiento.ejercicios
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
        
        // Asegurar que el ejercicio tenga un identificador único
        pe.id = UUID()
        
        context.insert(pe)
        entrenamiento.ejercicios.append(pe)
        
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

    // Estados locales para reps y weight string (por índice)
    @State private var repsStrings: [String] = []
    @State private var weightStrings: [String] = []

    var body: some View {
        let exerciseSeed = defaultExercises.first(where: { $0.slug == performedExercise.slug })
        
        List {
            let sortedSets = performedExercise.sets.sorted(by: { $0.order < $1.order })
            ForEach(Array(sortedSets.enumerated()), id: \.element.id) { index, set in
                HStack {
                    Text("Serie \(set.order + 1):")
                    Spacer()
                    TextField("Reps", text: Binding(
                        get: {
                            if index < repsStrings.count {
                                return repsStrings[index]
                            }
                            return ""
                        },
                        set: { newValue in
                            // Filtrar solo dígitos, max 3 chars para reps
                            let filtered = newValue.filter { "0123456789".contains($0) }
                            let limited = String(filtered.prefix(3))
                            if index < repsStrings.count {
                                repsStrings[index] = limited
                            }
                        }
                    ))
                    .disabled(isFinished)
                    .keyboardType(.numberPad)
                    .frame(width: 50)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: repsStrings) {
                        guard index < performedExercise.sets.count else { return }
                        if let intValue = Int(repsStrings[safe: index] ?? ""), intValue >= 0 {
                            performedExercise.sets[index].reps = intValue
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
                            // Filtrar caracteres válidos para decimal: dígitos y un solo punto
                            let filtered = newValue.filter { "0123456789.".contains($0) }
                            var clean = ""
                            var dotCount = 0
                            for char in filtered {
                                if char == "." {
                                    dotCount += 1
                                    if dotCount > 1 { continue }
                                }
                                clean.append(char)
                            }
                            // Limitar a 6 caracteres max para evitar textos largos
                            let limited = String(clean.prefix(6))
                            if index < weightStrings.count {
                                weightStrings[index] = limited
                            }
                        }
                    ))
                    .disabled(isFinished)
                    .keyboardType(.decimalPad)
                    .frame(width: 70)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: weightStrings) {
                        guard index < performedExercise.sets.count else { return }
                        if let doubleValue = Double(weightStrings[safe: index] ?? ""), doubleValue >= 0 {
                            performedExercise.sets[index].weight = doubleValue
                            saveContext()
                        }
                    }
                    Text("kg")
                }
                .contentShape(Rectangle())
            }
            .onDelete(perform: deleteSets)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text(exerciseSeed?.name ?? performedExercise.slug)
                        .font(.headline)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !isFinished {
                    Button("Añadir serie") {
                        addSet()
                    }
                }
            }
        }
        .onAppear {
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
    private func syncStringsWithModel() {
        let sortedSets = performedExercise.sets.sorted(by: { $0.order < $1.order })
        let newRepsStrings = sortedSets.map { String($0.reps) }
        let newWeightStrings = sortedSets.map { String(format: "%.1f", $0.weight) }
        
        // Actualizar solo si difiere para evitar redibujos innecesarios
        if newRepsStrings != repsStrings {
            repsStrings = newRepsStrings
        }
        if newWeightStrings != weightStrings {
            weightStrings = newWeightStrings
        }
    }

    private func addSet() {
        let newOrder = (performedExercise.sets.map { $0.order }.max() ?? -1) + 1
        let newSet = ExerciseSet(reps: 10, weight: 50, order: newOrder, performedExercise: performedExercise)
        newSet.id = UUID()
        context.insert(newSet)
        performedExercise.sets.append(newSet)
        saveContext()
        syncStringsWithModel()
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
        saveContext()
        syncStringsWithModel()
    }

    private func saveContext() {
        do {
            try context.save()
        } catch {
            print("❌ Error al guardar cambios en series: \(error)")
            context.rollback()
        }
    }
}

// Extension para acceso seguro a array indices sin causar crash
private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
