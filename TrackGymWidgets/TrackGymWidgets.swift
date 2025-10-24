//
//  TrackGymWidgets.swift
//  TrackGymWidgets
//
//  Created by Sergio Comerón on 17/8/25.
//

import WidgetKit
import SwiftUI
import Charts

enum MacroType: String, CaseIterable, Identifiable {
    case protein = "Proteína"
    case carbs = "Hidratos"
    case fat = "Grasas"
    var id: String { rawValue }
}

struct MacroDatum: Identifiable {
    let id = UUID()
    let macro: MacroType
    let consumed: Double   // gramos consumidos hoy
    let average: Double    // media histórica en gramos
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent(), data: Self.loadMacroData())
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration, data: Self.loadMacroData())
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let entry = SimpleEntry(date: Date(), configuration: configuration, data: Self.loadMacroData())

        // Refresh every 30 minutes to keep it current throughout the day
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    static func loadMacroData() -> [MacroDatum] {
        // Cambia este identifier por el de tu App Group si usas uno en producción
        let defaults = UserDefaults(suiteName: "group.com.sergiocomeron.trackgym") ?? .standard

        // Claves esperadas para valores de HOY (en gramos)
        let proteinToday = defaults.double(forKey: "proteinToday")
        let carbsToday = defaults.double(forKey: "carbsToday")
        let fatToday = defaults.double(forKey: "fatToday")

        // Medias históricas (en gramos)
        let proteinAvg = defaults.double(forKey: "proteinAvg")
        let carbsAvg = defaults.double(forKey: "carbsAvg")
        let fatAvg = defaults.double(forKey: "fatAvg")

        // Si no hay datos todavía, usa valores de muestra para que el widget no se vea vacío
        let pToday = proteinToday > 0 ? proteinToday : 140
        let cToday = carbsToday > 0 ? carbsToday : 220
        let fToday = fatToday > 0 ? fatToday : 60

        let pAvg = proteinAvg > 0 ? proteinAvg : 150
        let cAvg = carbsAvg > 0 ? carbsAvg : 250
        let fAvg = fatAvg > 0 ? fatAvg : 70

        return [
            MacroDatum(macro: .protein, consumed: pToday, average: pAvg),
            MacroDatum(macro: .carbs, consumed: cToday, average: cAvg),
            MacroDatum(macro: .fat, consumed: fToday, average: fAvg)
        ]
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let data: [MacroDatum]
}

struct TrackGymWidgetsEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Macros de hoy")
                .font(.caption)
                .bold()
            Chart(entry.data) { item in
                BarMark(
                    x: .value("Macro", item.macro.rawValue),
                    y: .value("Hoy (g)", item.consumed)
                )
                .cornerRadius(3)

                // Punto para la media de ese macro
                PointMark(
                    x: .value("Macro", item.macro.rawValue),
                    y: .value("Media (g)", item.average)
                )
                .symbolSize(40)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartLegend(.hidden)

            HStack(spacing: 8) {
                Label("Hoy", systemImage: "square.fill")
                    .labelStyle(.iconOnly)
                    .font(.caption2)
                Text("Barra = gramos hoy")
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Circle().frame(width: 6, height: 6)
                Text("Punto = media")
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(8)
    }
}

struct TrackGymWidgets: Widget {
    let kind: String = "TrackGymWidgets"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            TrackGymWidgetsEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

extension ConfigurationAppIntent {
    fileprivate static var smiley: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "😀"
        return intent
    }
    
    fileprivate static var starEyes: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "🤩"
        return intent
    }
}

#Preview(as: .systemSmall) {
    TrackGymWidgets()
} timeline: {
    SimpleEntry(date: .now, configuration: .smiley, data: Provider.loadMacroData())
    SimpleEntry(date: .now, configuration: .starEyes, data: Provider.loadMacroData())
}

#Preview(as: .systemLarge) {
    TrackGymWidgets()
} timeline: {
    SimpleEntry(date: .now, configuration: .smiley, data: Provider.loadMacroData())
    SimpleEntry(date: .now, configuration: .starEyes, data: Provider.loadMacroData())
}

#Preview(as: .systemExtraLarge) {
    TrackGymWidgets()
} timeline: {
    SimpleEntry(date: .now, configuration: .smiley, data: Provider.loadMacroData())
    SimpleEntry(date: .now, configuration: .starEyes, data: Provider.loadMacroData())
}
