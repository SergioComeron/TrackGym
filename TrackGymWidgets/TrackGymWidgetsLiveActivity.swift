//
//  TrackGymWidgetsLiveActivity.swift
//  TrackGymWidgets
//
//  Created by Sergio Comerón on 17/8/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TrackGymWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
//        ActivityConfiguration(for: TrackGymWidgetsAttributes.self) { context in
            ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in

            // Lock screen/banner UI goes here
            VStack {
                Text("Entrenamiento iniciado a  \(context.state.startedAt)")

            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Inicio a \(context.state.startedAt)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.startedAt)")
            } minimal: {
                Text("\(context.state.startedAt)")
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
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
