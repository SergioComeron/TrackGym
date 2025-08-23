//  ProgresoView.swift
//  TrackGym
//  Visualización de progreso de entrenamientos

import SwiftUI
import SwiftData
import FoundationModels
#if canImport(Charts)
import Charts
#endif

struct ProgresoView: View {
    @Query(sort: [SortDescriptor(\Entrenamiento.startDate, order: .reverse)])
    private var entrenamientos: [Entrenamiento]
    
    @State private var selectedSlug: String? = nil
    @State private var resumenEntrenoHoy: String? = nil
    @State private var cargandoResumenEntrenoHoy = false
    @State private var lastResumenEntrenoID: UUID? = nil
    
    private let resumenEntrenoKey = "ResumenEntrenoHoy"
    private let resumenEntrenoIDKey = "LastResumenEntrenoID"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                if cargandoResumenEntrenoHoy {
                    GroupBox(label: Label("Resumen de tu último entrenamiento (AI)", systemImage: "sparkles")) {
                        ProgressView()
                            .padding(.vertical, 8)
                    }
                } else if let resumen = resumenEntrenoHoy {
                    GroupBox(label: Label("Resumen de tu último entrenamiento (AI)", systemImage: "sparkles")) {
                        Text(resumen)
                            .font(.callout)
                            .padding(.vertical, 8)
                    }
                }

                HStack(spacing: 16) {
                    resumenBox(title: "Entrenos", value: "\(entrenamientosTerminados.count)", color: .blue)
                    resumenBox(title: "Total", value: formatDuration(seconds: totalDuracion), color: .green)
                    resumenBox(title: "Media", value: formatDuration(seconds: mediaDuracion), color: .orange)
                }
                .padding(.top, 8)

                #if canImport(Charts)
                if entrenamientosTerminados.count > 1 {
                    ChartSection(entrenamientos: entrenamientosTerminados)
                }
                #endif

                GroupBox(label: Label("Progreso por ejercicio", systemImage: "figure.strengthtraining.traditional")) {
                    if slugsEjerciciosRealizados.isEmpty {
                        Text("Añade un ejercicio en un entrenamiento para ver tus gráficos y marcas aquí.")
                            .font(.callout)
                            .padding(.vertical, 12)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Ejercicio seleccionado", selection: Binding(
                                get: { selectedSlug ?? slugsEjerciciosRealizados.first! },
                                set: { selectedSlug = $0 })
                            ) {
                                ForEach(slugsEjerciciosRealizados, id: \.self) { slug in
                                    Text(nombreEjercicioDesdeSlug(slug)).tag(slug as String?)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()

                            if let slug = selectedSlug ?? slugsEjerciciosRealizados.first {
                                resumenEjercicioSeleccionado(slug: slug)
                                #if canImport(Charts)
                                PesoChartView(slug: slug, entrenamientos: entrenamientosTerminados)
                                #endif
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if entrenamientosTerminados.isEmpty {
                    ContentUnavailableView(
                        "Aún no tienes entrenos finalizados",
                        systemImage: "chart.bar.doc.horizontal",
                        description: Text("Termina tu primer entreno para ver tu progreso aquí.")
                    )
                    .padding(.vertical)
                }
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal)
            .padding(.vertical, 22)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Progreso")
        .onAppear {
            if selectedSlug == nil, let primero = ejercicioMasFrecuenteSlug ?? slugsEjerciciosRealizados.first {
                selectedSlug = primero
            }
            if let storedID = UserDefaults.standard.string(forKey: resumenEntrenoIDKey),
               let uuid = UUID(uuidString: storedID) {
                lastResumenEntrenoID = uuid
            }
            resumenEntrenoHoy = UserDefaults.standard.string(forKey: resumenEntrenoKey)
            generarResumenEntrenoHoy()
        }
    }

    private var entrenamientosTerminados: [Entrenamiento] {
        entrenamientos.filter { $0.endDate != nil && $0.startDate != nil }
    }

    private var totalDuracion: TimeInterval {
        entrenamientosTerminados.reduce(0) { sum, e in
            guard let start = e.startDate, let end = e.endDate else { return sum }
            return sum + end.timeIntervalSince(start)
        }
    }
    
    private var mediaDuracion: TimeInterval {
        guard !entrenamientosTerminados.isEmpty else { return 0 }
        return totalDuracion / Double(entrenamientosTerminados.count)
    }

    private var slugsEjerciciosRealizados: [String] {
        let ejercicios = entrenamientosTerminados.flatMap { $0.ejercicios }
        let slugs = ejercicios.map { $0.slug }
        return Array(Set(slugs)).sorted()
    }
    
    private func resumenEjercicioSeleccionado(slug: String) -> some View {
        let ejercicios = entrenamientosTerminados.flatMap { $0.ejercicios }.filter { $0.slug == slug }
        let series = ejercicios.flatMap { $0.sets }
        return Group {
            if series.isEmpty {
                Text("Aún no has registrado este ejercicio.")
                    .font(.callout).foregroundStyle(.secondary).padding(.top, 8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mejores marcas: \(nombreEjercicioDesdeSlug(slug))").font(.headline)
                    let maxPeso = series.max(by: { $0.weight < $1.weight })?.weight ?? 0
                    let maxReps = series.max(by: { $0.reps < $1.reps })?.reps ?? 0
                    HStack {
                        Text("Peso: \(String(format: "%.1f", maxPeso)) kg").font(.body)
                        Spacer()
                        Text("Reps: \(maxReps)").font(.body)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private var ejercicioMasFrecuenteSlug: String? {
        let ejercicios = entrenamientosTerminados.flatMap { $0.ejercicios }
        let counts = Dictionary(grouping: ejercicios, by: { $0.slug }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private var resumenVisual: some View {
        HStack(spacing: 16) {
            resumenBox(title: "Entrenos", value: "\(entrenamientosTerminados.count)", color: .blue)
            resumenBox(title: "Total", value: formatDuration(seconds: totalDuracion), color: .green)
            resumenBox(title: "Media", value: formatDuration(seconds: mediaDuracion), color: .orange)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func resumenBox(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
    }

    private func duracionText(from start: Date, to end: Date) -> String {
        let interval = Int(end.timeIntervalSince(start))
        let h = interval / 3600
        let m = (interval % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        } else {
            return "\(m)m"
        }
    }
    
    private func formatDuration(seconds: TimeInterval) -> String {
        let s = Int(seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        } else {
            return "\(m)m"
        }
    }

    private func generarResumenEntrenoHoy() {
        cargandoResumenEntrenoHoy = true
        guard let entreno = entrenamientosTerminados.first else {
            cargandoResumenEntrenoHoy = false
            return
        }
        let currentID = entreno.id
        if currentID == lastResumenEntrenoID, resumenEntrenoHoy != nil {
            cargandoResumenEntrenoHoy = false
            return
        }
        resumenEntrenoHoy = nil
        let grupos = entreno.gruposMusculares.map { $0.localizedName }.joined(separator: ", ")
        let ejerciciosStr = entreno.ejercicios.map { ejercicio -> String in
            let exerciseSeed = defaultExercises.first(where: { $0.slug == ejercicio.slug })
            let setsText = ejercicio.sets.map { set -> String in
                if let seed = exerciseSeed {
                    switch seed.type {
                    case .duration:
                        return "\(Int(set.reps))seg@\(String(format: "%.1f", set.weight))kg"
                    case .reps:
                        return "\(set.reps)x\(String(format: "%.1f", set.weight))kg"
                    }
                } else {
                    // Por defecto reps
                    return "\(set.reps)x\(String(format: "%.1f", set.weight))kg"
                }
            }.joined(separator: ", ")
            return "\(nombreEjercicioDesdeSlug(ejercicio.slug)): \(setsText)"
        }.joined(separator: "\n")
        let gruposTrabajados = Set(entreno.gruposMusculares)
        let ejerciciosDisponibles = defaultExercises.filter { gruposTrabajados.contains($0.group) }
            .map { $0.name }
            .joined(separator: ", ")
        

        let prompt = "Eres un entrenador personal de gimnasio avanzado, experto en cambios físicos para aumemntar masa muscular o perder grasa. Analiza este entrenamiento de hoy:\n- Grupos trabajados: \(grupos)\n- Ejercicios realizados:\n\(ejerciciosStr)\nDime si he hecho bien el entreno para trabajar los musculos que te he dicho. Estas repeticiones y pesos están bien? Si ves que falta algun otro ejercicio proponme alguno de esta lista: \(ejerciciosDisponibles).\nEsplicame por qué lo sugieres y si no es necesario dime por qué he hecho bien este entrenamiento. Sé claro, directo y concreto en español.\nToda tu respuesta no puede ocupar mas de dos párrafos"
        print(prompt)
        Task {
            let session = LanguageModelSession(instructions: "Eres un entrenador personal crítico, experto en mejora física y fuerza. Da consejos realistas, analiza posibles errores y propone cambios concretos. Responde en español.")
            if let respuesta = try? await session.respond(to: prompt) {
                await MainActor.run {
                    resumenEntrenoHoy = respuesta.content
                    lastResumenEntrenoID = currentID
                    UserDefaults.standard.setValue(currentID.uuidString, forKey: resumenEntrenoIDKey)
                    UserDefaults.standard.setValue(respuesta.content, forKey: resumenEntrenoKey)
                }
            }
            await MainActor.run { cargandoResumenEntrenoHoy = false }
        }
    }
}

private func nombreEjercicioDesdeSlug(_ slug: String) -> String {
    if let seed = defaultExercises.first(where: { $0.slug == slug }) {
        return seed.name
    }
    return slug
}

#if canImport(Charts)
private struct ChartSection: View {
    let entrenamientos: [Entrenamiento]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Duración últimos entrenos")
                .font(.headline)
            
            Chart(entrenamientos.prefix(14), id: \Entrenamiento.id) { e in
                if let start = e.startDate, let end = e.endDate {
                    BarMark(
                        x: .value("Fecha", start, unit: .day),
                        y: .value("Duración", end.timeIntervalSince(start) / 60)
                    )
                    .foregroundStyle(Color.accentColor)
                }
            }
            .chartYAxisLabel("minutos", position: .trailing, alignment: .center)
            .frame(height: 180)
        }
    }
}
#endif

#if canImport(Charts)
private struct PesoChartView: View {
    let slug: String
    let entrenamientos: [Entrenamiento]
    
    var body: some View {
        let sets = entrenamientos
            .flatMap { $0.ejercicios }
            .filter { $0.slug == slug }
            .flatMap { $0.sets }
            .sorted(by: { $0.createdAt < $1.createdAt })
        
        let exerciseSeed = defaultExercises.first(where: { $0.slug == slug })
        
        VStack(alignment: .leading, spacing: 12) {
            if let seed = exerciseSeed, seed.type == .duration {
                Text("Evolución duración: \(nombreEjercicioDesdeSlug(slug))")
                    .font(.headline)
                if sets.isEmpty {
                    Text("No hay datos para este ejercicio.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Chart(sets, id: \.createdAt) { set in
                        PointMark(
                            x: .value("Fecha", set.createdAt),
                            y: .value("Duración", set.duration)
                        )
                        .foregroundStyle(Color.accentColor)
                    }
                    .chartYAxisLabel("segundos", position: .trailing, alignment: .center)
                    .frame(height: 180)
                }
            } else {
                Text("Evolución peso: \(nombreEjercicioDesdeSlug(slug))")
                    .font(.headline)
                if sets.isEmpty {
                    Text("No hay datos para este ejercicio.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Chart(sets, id: \.createdAt) { set in
                        PointMark(
                            x: .value("Fecha", set.createdAt),
                            y: .value("Peso", set.weight)
                        )
                        .foregroundStyle(Color.accentColor)
                    }
                    .chartYAxisLabel("kg", position: .trailing, alignment: .center)
                    .frame(height: 180)
                }
            }
        }
        .padding(.top, 16)
    }
}
#endif

#Preview {
    ProgresoView()
}
