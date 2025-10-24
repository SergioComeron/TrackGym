//
//  TrackGymWidgetsLiveActivity.swift
//  TrackGymWidgets
//
//  Created by Sergio Comerón on 17/8/25.
//


import ActivityKit
import WidgetKit
import SwiftUI

private extension Date {
    var shortDateTime: String { self.formatted(date: .abbreviated, time: .shortened) }
    var shortTime: String { self.formatted(date: .omitted, time: .shortened) }
    var dayAndTime: String { self.formatted(.dateTime.weekday(.abbreviated).hour().minute()) }
}

struct TrackGymWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            TimelineView(.periodic(from: context.state.startedAt, by: 60)) { _ in
                // Lock screen / banner (Live Activity) UI
                let started = context.state.startedAt

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(started.dayAndTime)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if let n = context.state.ultimaSerieNumero {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Serie \(n)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if let d = context.state.ultimaSerieDuracion {
                                    Text("\(d) seg")
                                        .font(.largeTitle)
                                        .fontWeight(.bold)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                } else if let r = context.state.ultimaSerieReps,
                                          let p = context.state.ultimaSeriePeso {
                                    Text("\(r)x\(String(format: "%.1f", p)) kg")
                                        .font(.largeTitle)
                                        .fontWeight(.bold)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                }
                            }
                        }
                    }
                    if let nombre = context.state.ejercicioActualNombre {
                        Text(nombre)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ProgressView(value: context.state.progress)
                        .progressViewStyle(.linear)
                        .animation(.easeInOut(duration: 0.5), value: context.state.progress)
                    Text("Progreso: \(Int(context.state.progress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .widgetURL(
                URL(string: "trackgym://live-activity?entrenamiento=\(context.attributes.entrenamientoID.uuidString)")
            )
//            .activityBackgroundTint(Color(.systemBackground))
//            .activitySystemActionForegroundColor(.accentColor)

        } dynamicIsland: { context in

            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .imageScale(.large)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        if let n = context.state.ultimaSerieNumero {
                            VStack(alignment: .trailing, spacing: 0) {
                                Text("Serie \(n)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if let d = context.state.ultimaSerieDuracion {
                                    Text("\(d) seg")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                } else if let r = context.state.ultimaSerieReps,
                                          let p = context.state.ultimaSeriePeso {
                                    Text("\(r)x\(String(format: "%.1f", p)) kg")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                }
                            }
                        } else {
                            Text(context.state.startedAt.dayAndTime)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.trailing, 12)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TimelineView(.periodic(from: context.state.startedAt, by: 60)) { timeline in
                        VStack(alignment: .leading, spacing: 4) {
                            if let nombre = context.state.ejercicioActualNombre {
                                Text(nombre)
                                    .font(.headline)
                                    .lineLimit(2)
                            }
                            HStack(spacing: 8) {
                                Spacer(minLength: 0)
                                Text("Progreso: \(Int(context.state.progress * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                    }
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
            } compactTrailing: {
                TimelineView(.periodic(from: context.state.startedAt, by: 60)) { _ in
                    Text("\(Int(context.state.progress * 100))%")
                        .monospacedDigit()
                        .font(.caption2)
                }
            } minimal: {
                Image(systemName: "figure.strengthtraining.traditional")
            }
            .widgetURL(
                URL(string: "trackgym://live-activity?entrenamiento=\(context.attributes.entrenamientoID.uuidString)")
            )
//            .keylineTint(.accentColor)
        }
    }
}

extension WorkoutActivityAttributes {
    fileprivate static var preview: WorkoutActivityAttributes {
        WorkoutActivityAttributes(entrenamientoID: UUID(), title: "Entrenamiento prueba")
    }
}

extension WorkoutActivityAttributes.ContentState {
    fileprivate static var smiley: WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            startedAt: Date().addingTimeInterval(-1200), // hace 20 minutos
            endedAt: nil,
            progress: 0.66,
            ejercicioActualID: UUID(),
            ejercicioActualNombre: "Press banca",
            ultimaSerieNumero: 3,
            ultimaSerieReps: 12,
            ultimaSeriePeso: 60.0
        )
    }
     
    fileprivate static var starEyes: WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            startedAt: Date().addingTimeInterval(-1700), // hace 28 minutos
            endedAt: nil,
            progress: 0.9,
            ejercicioActualID: UUID(),
            ejercicioActualNombre: "Remo con barra",
            ultimaSerieNumero: 4,
            ultimaSerieReps: 8,
            ultimaSeriePeso: 80.0
        )
    }
}

#Preview("Notification", as: .content, using: WorkoutActivityAttributes.preview) {
   TrackGymWidgetsLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.smiley
    WorkoutActivityAttributes.ContentState.starEyes
}

