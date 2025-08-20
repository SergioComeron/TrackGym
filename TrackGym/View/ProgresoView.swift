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
                    ContentUnavailableView("Aún no tienes entrenos finalizados","chart.bar.doc.horizontal",
                        description: Text("Termina tu primer entreno para ver tu progreso aquí."))
                }
            }
            .padding()
        }
        .navigationTitle("Progreso")
        .background(Color(.systemGroupedBackground))
    }

    private var entrenamientosTerminados: [Entrenamiento] {
        entrenamientos.filter { $0.endDate != nil && $0.startDate != nil }
    }

    private var totalDuracion: TimeInterval {
        entrenamientosTerminados.reduce(0) { sum, e in
            let start = e.startDate!; let end = e.endDate!
            return sum + end.timeIntervalSince(start)
        }
    }
    private var mediaDuracion: TimeInterval {
        guard !entrenamientosTerminados.isEmpty else { return 0 }
        return totalDuracion / Double(entrenamientosTerminados.count)
    }

    private var resumenVisual: some View {
        HStack(spacing: 24) {
            resumenBox(title: "Entrenos", value: "\(entrenamientosTerminados.count)", color: .blue)
            resumenBox(title: "Total", value: formatDuration(seconds: totalDuracion), color: .green)
            resumenBox(title: "Media", value: formatDuration(seconds: mediaDuracion), color: .orange)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func resumenBox(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value).font(.title).fontWeight(.bold).foregroundColor(color)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func duracionText(from start: Date, to end: Date) -> String {
        let interval = Int(end.timeIntervalSince(start))
        let h = interval / 3600; let m = (interval % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" } else { return "\(m)m" }
    }
    private func formatDuration(seconds: TimeInterval) -> String {
        let s = Int(seconds)
        let m = (s % 3600) / 60
        let h = s / 3600
        if h > 0 { return "\(h)h \(m)m" } else { return "\(m)m" }
    }
}

#if canImport(Charts)
private struct ChartSection: View {
    let entrenamientos: [Entrenamiento]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Duración últimos entrenos").font(.headline)
            Chart(entrenamientos.prefix(14), id: \Entrenamiento.id) { e in
                if let start = e.startDate, let end = e.endDate {
                    BarMark(
                        x: .value("Fecha", start, unit: .day),
                        y: .value("Duración", end.timeIntervalSince(start) / 60)
                    ).foregroundStyle(.accent)
                }
            }
            .chartYAxisLabel("minutos", position: .trailing, alignment: .center)
            .frame(height: 180)
        }
    }
}
#endif

#Preview {
    ProgresoView()
}
