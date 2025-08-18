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
}

struct TrackGymWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // Lock screen / banner (Live Activity) UI
            let started = context.state.startedAt

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
                    Text(context.attributes.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text("Inicio: \(started.shortDateTime)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .widgetURL(
                URL(string: "trackgym://live-activity?entrenamiento=\(context.attributes.entrenamientoID.uuidString)")
            )
            .activityBackgroundTint(Color(.systemBackground))
            .activitySystemActionForegroundColor(.accentColor)

        } dynamicIsland: { context in

            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .imageScale(.large)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Inicio")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(context.state.startedAt.shortTime)
                            .font(.caption)
                            .monospacedDigit()
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        Text(context.attributes.title)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        Text("Desde \(context.state.startedAt.shortTime)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
            } compactTrailing: {
                Text(context.state.startedAt.shortTime)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "figure.strengthtraining.traditional")
            }
            .widgetURL(
                URL(string: "trackgym://live-activity?entrenamiento=\(context.attributes.entrenamientoID.uuidString)")
            )
            .keylineTint(.accentColor)
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
        WorkoutActivityAttributes.ContentState(startedAt: Date())
     }
     
     fileprivate static var starEyes: WorkoutActivityAttributes.ContentState {
         WorkoutActivityAttributes.ContentState(startedAt: Date())
     }
}

#Preview("Notification", as: .content, using: WorkoutActivityAttributes.preview) {
   TrackGymWidgetsLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.smiley
    WorkoutActivityAttributes.ContentState.starEyes
}
