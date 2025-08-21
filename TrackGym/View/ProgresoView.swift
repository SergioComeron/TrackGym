//  ProgresoView.swift
//  TrackGym
//  Visualización de progreso de entrenamientos

import SwiftUI
import SwiftData
#if canImport(Charts)
import Charts
#endif

struct ProgresoView: View {
    @Query(sort: [SortDescriptor(\Entrenamiento.startDate, order: .reverse)])
    private var entrenamientos: [Entrenamiento]
    
    // 1. Cambia la inicialización de selectedSlug para que dependa del primer slug disponible (el más frecuente si es posible) y quita el valor "" por defecto:
    @State private var selectedSlug: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                resumenVisual
                
                #if canImport(Charts)
                if entrenamientosTerminados.count > 1 {
                    ChartSection(entrenamientos: entrenamientosTerminados)
                }
                #endif
                
                Text("Historial reciente")
                    .font(.headline)
                
                // 2. Mejora la UI del selector y la sección de datos:
                // Sustituye el bloque del Picker+resumenEjercicioSeleccionado+PesoChartView por lo siguiente:
                GroupBox(label: Label("Progreso por ejercicio", systemImage: "figure.strengthtraining.traditional")) {
                    if slugsEjerciciosRealizados.isEmpty {
                        Text("Añade un ejercicio en un entrenamiento para ver tus gráficos y marcas aquí.")
                            .font(.callout).padding(.vertical, 12)
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
                            .padding(.bottom, 6)
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
                .padding(.bottom, 16)
                
                ForEach(entrenamientosTerminados.prefix(7)) { e in
                    if let start = e.startDate, let end = e.endDate {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(DateFormatter.cachedDateTime.string(from: start))
                                    .font(.subheadline)
                                Text("Duración: " + duracionText(from: start, to: end))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
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
                }
            }
            .padding()
        }
        .navigationTitle("Progreso")
        .background(Color(.systemGroupedBackground))
        // 4. Modifica onAppear para inicializar selectedSlug solo si hay ejercicios y aún está a nil:
        .onAppear {
            if selectedSlug == nil, let primero = ejercicioMasFrecuenteSlug ?? slugsEjerciciosRealizados.first {
                selectedSlug = primero
            }
        }
    }

    private var entrenamientosTerminados: [Entrenamiento] {
        entrenamientos.filter { $0.endDate != nil && $0.startDate != nil }
    }

    private var totalDuracion: TimeInterval {
        entrenamientosTerminados.reduce(0) { sum, e in
            // Usar guard para evitar force unwrapping
            guard let start = e.startDate, let end = e.endDate else { return sum }
            return sum + end.timeIntervalSince(start)
        }
    }
    
    private var mediaDuracion: TimeInterval {
        guard !entrenamientosTerminados.isEmpty else { return 0 }
        return totalDuracion / Double(entrenamientosTerminados.count)
    }

    // 2. Añade una propiedad computada para obtener los slugs de ejercicios realmente realizados
    private var slugsEjerciciosRealizados: [String] {
        let ejercicios = entrenamientosTerminados.flatMap { $0.ejercicios }
        let slugs = ejercicios.map { $0.slug }
        return Array(Set(slugs)).sorted()
    }
    
    // 3. Cambia resumenEjercicioSeleccionado a función que recibe slug:
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
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        
        VStack(alignment: .leading, spacing: 12) {
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
        .padding(.top, 16)
    }
}
#endif

#Preview {
    ProgresoView()
}
