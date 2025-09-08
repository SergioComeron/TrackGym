//
//  EntrenamientoDetailView.swift
//  TrackGym
//
//  Created by Sergio Comerón on 8/9/25.
//

import SwiftUI
import SwiftData

struct EntrenamientoDetailView: View {
    let entrenamiento: Entrenamiento
    @Environment(\.modelContext) private var context
    @State private var repsInput: [UUID: Int] = [:]
    @State private var weightInput: [UUID: Double] = [:]
    @State private var selectedExerciseIndex: Int = 0
    @State private var goToEnCurso: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                NavigationLink(isActive: $goToEnCurso) {
                    EntrenamientoEnCursoWatchView(entrenamiento: entrenamiento)
                } label: { EmptyView() }
                .hidden()

                if entrenamiento.startDate == nil || entrenamiento.endDate == nil {
                    Button {
                        if entrenamiento.startDate == nil {
                            entrenamiento.startDate = Date()
                            do {
                                try context.save()
                                goToEnCurso = true
                            } catch {
                                if entrenamiento.startDate == nil {
                                    print("❌ Error al iniciar entrenamiento: \(error)")
                                } else {
                                    print("❌ Error al finalizar entrenamiento: \(error)")
                                }
                            }
                        } else if entrenamiento.endDate == nil {
                            entrenamiento.endDate = Date()
                            do { try context.save() } catch {
                                print("❌ Error al finalizar entrenamiento: \(error)")
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: entrenamiento.startDate == nil ? "play.fill" : "stop.fill")
                            Text(entrenamiento.startDate == nil ? "Iniciar entrenamiento" : "Finalizar entrenamiento")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 10)
                        .background((entrenamiento.startDate == nil ? Color.accentColor.opacity(0.2) : Color.red.opacity(0.15)), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

                // Si ya está iniciado y no terminado, ofrecer ir a la vista en curso
                if entrenamiento.startDate != nil && entrenamiento.endDate == nil {
                    Button {
                        goToEnCurso = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "figure.strengthtraining.functional")
                            Text("Abrir ejercicios")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 10)
                        .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("Entrenamiento")
    }
}

private struct ExerciseCard: View {
    let ejercicio: PerformedExercise
    @Binding var reps: Int
    @Binding var weight: Double
    @Environment(\.modelContext) private var context
    @State private var setToEdit: ExerciseSet? = nil
    @State private var showEditSheet: Bool = false
    var onAdd: (Int, Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack(spacing: 12) {
                RoundIconButton(systemName: "minus") { reps = max(1, reps - 1) }
                VStack(spacing: 2) {
                    Text("Reps")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(reps)")
                        .font(.headline)
                        .monospacedDigit()
                }
                RoundIconButton(systemName: "plus") { reps = min(100, reps + 1) }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                RoundIconButton(systemName: "minus") { weight = max(0, weight - 2.5) }
                VStack(spacing: 2) {
                    Text("Peso (kg)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(formatWeight(weight))
                        .font(.headline)
                        .monospacedDigit()
                }
                RoundIconButton(systemName: "plus") { weight = min(500, weight + 2.5) }
            }
            .frame(maxWidth: .infinity)

            Button {
                onAdd(reps, weight)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Añadir serie")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.2)))
            }
            .buttonStyle(.plain)

            // Últimas series (si las hay)
            if let sets = ejercicio.sets, !sets.isEmpty {
                let todas = sets.sorted { $0.order < $1.order }
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(todas, id: \.id) { s in
                        HStack {
                            Text("• \(s.reps) reps × \(String(format: "%.1f", s.weight)) kg")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            setToEdit = s
                            showEditSheet = true
                        }
                    }
                }
                .padding(.top, 2)
                .sheet(isPresented: $showEditSheet) {
                    if let target = setToEdit {
                        EditSetSheet(set: target) { newReps, newWeight in
                            target.reps = newReps
                            target.weight = newWeight
                            do { try context.save() } catch { print("❌ Error guardando edición: \(error)") }
                        } onDelete: {
                            if let idx = (ejercicio.sets ?? []).firstIndex(where: { $0.id == target.id }) {
                                ejercicio.sets?.remove(at: idx)
                            }
                            context.delete(target)
                            do { try context.save() } catch { print("❌ Error eliminando serie: \(error)") }
                        }
                    } else {
                        Text("Sin serie seleccionada")
                    }
                }
            }
        }
        .padding(12)
        
    }

    private var ejercicioNombre: String {
        let key = "\(ejercicio.slug)_name"
        let localized = NSLocalizedString(key, comment: "")
        if localized == key { // Fallback si no hay traducción
            return ejercicio.slug.replacingOccurrences(of: "_", with: " ").capitalized
        }
        return localized
    }

    private func formatWeight(_ value: Double) -> String {
        let s = String(format: "%.1f", value)
        return s.replacingOccurrences(of: ".0", with: "")
    }

    private struct RoundIconButton: View {
        let systemName: String
        let action: () -> Void
        var body: some View {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.headline)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .background(
                Circle().fill(Color.secondary.opacity(0.2))
            )
            .clipShape(Circle())
        }
    }
}

private struct EditSetSheet: View {
    let set: ExerciseSet
    @State private var reps: Int
    @State private var weight: Double
    var onSave: (Int, Double) -> Void
    var onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    init(set: ExerciseSet, onSave: @escaping (Int, Double) -> Void, onDelete: @escaping () -> Void) {
        self.set = set
        self._reps = State(initialValue: set.reps)
        self._weight = State(initialValue: set.weight)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(NSLocalizedString("Editar serie", comment: "")).font(.headline)

            // Reps editor (compact, watch-friendly)
            HStack(spacing: 12) {
                RoundIconButton(systemName: "minus") { reps = max(1, reps - 1) }
                VStack(spacing: 2) {
                    Text("Reps").font(.caption2).foregroundStyle(.secondary)
                    Text("\(reps)").font(.headline).monospacedDigit()
                }
                RoundIconButton(systemName: "plus") { reps = min(100, reps + 1) }
            }

            // Weight editor
            HStack(spacing: 12) {
                RoundIconButton(systemName: "minus") { weight = max(0, weight - 2.5) }
                VStack(spacing: 2) {
                    Text("Peso (kg)").font(.caption2).foregroundStyle(.secondary)
                    Text(formatWeight(weight)).font(.headline).monospacedDigit()
                }
                RoundIconButton(systemName: "plus") { weight = min(500, weight + 2.5) }
            }

            Button {
                onSave(reps, weight)
                dismiss()
            } label: {
                Label("Guardar", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.2)))
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                onDelete()
                dismiss()
            } label: {
                Label("Eliminar", systemImage: "trash")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
        .padding()
    }

    private func formatWeight(_ value: Double) -> String {
        let s = String(format: "%.1f", value)
        return s.replacingOccurrences(of: ".0", with: "")
    }
}

private struct RoundIconButton: View {
    let systemName: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.headline)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .background(
            Circle().fill(Color.secondary.opacity(0.2))
        )
        .clipShape(Circle())
    }
}

private extension EntrenamientoDetailView {
    func addSet(reps: Int, weight: Double, to ejercicio: PerformedExercise) {
        let order = (ejercicio.sets?.count ?? 0) + 1
        let nuevo = ExerciseSet(reps: reps, weight: weight, order: order, duration: 0, performedExercise: ejercicio, createdAt: Date())
        context.insert(nuevo)
        if ejercicio.sets == nil { ejercicio.sets = [] }
        ejercicio.sets?.append(nuevo)
        do { try context.save(); print("✅ Serie añadida: reps=\(reps), peso=\(weight)") } catch { print("❌ Error guardando serie: \(error)"); context.rollback() }
    }
}

// MARK: - Vista en curso a pantalla completa
struct EntrenamientoEnCursoWatchView: View {
    let entrenamiento: Entrenamiento
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var repsInput: [UUID: Int] = [:]
    @State private var weightInput: [UUID: Double] = [:]
    @State private var selectedIndex: Int = 0

    var body: some View {
        let ejercicios = (entrenamiento.ejercicios ?? []).sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt { return lhs.order < rhs.order }
            return lhs.createdAt < rhs.createdAt
        }
        let currentTitle = selectedIndex < ejercicios.count ? exerciseName(for: ejercicios[selectedIndex]) : NSLocalizedString("Finalizar", comment: "")
        VStack(spacing: 8) {
            if ejercicios.isEmpty {
                ContentUnavailableView("Sin ejercicios", systemImage: "dumbbell")
            } else {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(ejercicios.enumerated()), id: \.element.id) { index, ej in
                        ScrollView {
                            ExerciseCard(
                                ejercicio: ej,
                                reps: Binding(get: { repsInput[ej.id] ?? 10 }, set: { repsInput[ej.id] = $0 }),
                                weight: Binding(get: { weightInput[ej.id] ?? 20 }, set: { weightInput[ej.id] = $0 }),
                                onAdd: { reps, weight in
                                    addSet(reps: reps, weight: weight, to: ej)
                                }
                            )
                            .padding(.horizontal)
                            .padding(.bottom, 12)
                        }
                        .tag(index)
                    }

                    // Página final: finalizar
                    FinalizarCard {
                        entrenamiento.endDate = Date()
                        do { try context.save() } catch { print("❌ Error al finalizar: \(error)") }
                        dismiss()
                    }
                    .tag(ejercicios.count)
                    .padding(.horizontal)
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page)            }
        }
        .navigationTitle(currentTitle)
        .safeAreaPadding(.top, 16)
    }

    private func addSet(reps: Int, weight: Double, to ejercicio: PerformedExercise) {
        let order = (ejercicio.sets?.count ?? 0) + 1
        let nuevo = ExerciseSet(reps: reps, weight: weight, order: order, duration: 0, performedExercise: ejercicio, createdAt: Date())
        context.insert(nuevo)
        if ejercicio.sets == nil { ejercicio.sets = [] }
        ejercicio.sets?.append(nuevo)
        do { try context.save() } catch { print("❌ Error guardando serie: \(error)") }
    }
    
    private func exerciseName(for ejercicio: PerformedExercise) -> String {
        let key = "\(ejercicio.slug)_name"
        let localized = NSLocalizedString(key, comment: "")
        if localized == key { return ejercicio.slug.replacingOccurrences(of: "_", with: " ").capitalized }
        return localized
    }
}

private struct FinalizarCard: View {
    var onFinish: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 36))
            Text("Finalizar entrenamiento")
                .font(.headline)
            Button(action: onFinish) {
                Label("Finalizar", systemImage: "stop.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }
}

#if DEBUG
#Preview("Pendiente") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Entrenamiento.self, configurations: config)
    let ctx = container.mainContext
    let e = Entrenamiento(id: UUID(), startDate: nil, endDate: nil)
    let sentadilla = PerformedExercise(slug: "sentadilla", entrenamiento: e)
    let jalon     = PerformedExercise(slug: "jalon_pecho", entrenamiento: e)
    e.ejercicios = [sentadilla, jalon]
    ctx.insert(e)
    ctx.insert(sentadilla)
    ctx.insert(jalon)
    return NavigationStack { EntrenamientoDetailView(entrenamiento: e) }
        .modelContainer(container)
}

#Preview("En curso") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Entrenamiento.self, configurations: config)
    let ctx = container.mainContext
    let e = Entrenamiento(id: UUID(), startDate: Date().addingTimeInterval(-1800), endDate: nil)
    // Añadir ejercicios y sets de ejemplo
    let press = PerformedExercise(slug: "press_banca", entrenamiento: e)
    let remo  = PerformedExercise(slug: "remo_barra", entrenamiento: e)

    let set1 = ExerciseSet(reps: 10, weight: 60, order: 1, duration: 0, performedExercise: press)
    let set2 = ExerciseSet(reps: 8,  weight: 70, order: 2, duration: 0, performedExercise: press)
    press.sets = [set1, set2]
    remo.sets = []

    e.ejercicios = [press, remo]
    ctx.insert(e)
    ctx.insert(press)
    ctx.insert(remo)
    ctx.insert(set1)
    ctx.insert(set2)
    return NavigationStack { EntrenamientoDetailView(entrenamiento: e) }
        .modelContainer(container)
}

#Preview("Terminado") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Entrenamiento.self, configurations: config)
    let ctx = container.mainContext
    let e = Entrenamiento(id: UUID(), startDate: Date().addingTimeInterval(-5400), endDate: Date().addingTimeInterval(-1800))
    ctx.insert(e)
    return NavigationStack { EntrenamientoDetailView(entrenamiento: e) }
        .modelContainer(container)
}
#endif
