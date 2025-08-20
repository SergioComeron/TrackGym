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
                        if let seed = defaultExercises.first(where: { $0.slug == pe.slug }) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(seed.name).font(.headline)
                                Text(seed.desc).font(.caption).foregroundStyle(.secondary)
                            }
                        } else {
                            Text(pe.slug) // Fallback si no existe en el catálogo
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

