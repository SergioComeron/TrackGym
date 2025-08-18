//
//  LiveActivityManager.swift
//  TrackGym
//
//  Created by Sergio Comerón on 18/8/25.
//

import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    private var currentActivity: Activity<WorkoutActivityAttributes>?

    func start(title: String, startedAt: Date, entrenamientoID: UUID) async {
        // Si ya hay una en marcha, la cerramos primero (opcional)
        if let act = currentActivity {
            await end(activity: act, dismissalPolicy: .immediate)
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities desactivadas en este dispositivo/usuario.")
            return
        }

        let attributes = WorkoutActivityAttributes(entrenamientoID: entrenamientoID, title: title)
        let state = WorkoutActivityAttributes.ContentState(startedAt: startedAt)
        let stale = Calendar.current.date(byAdding: .hour, value: 3, to: Date())
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: stale),
                pushType: nil // usa .token si vas a actualizar por push
            )
            self.currentActivity = activity
            print("Live Activity iniciada: \(activity.id)")
        } catch {
            print("Error iniciando Live Activity: \(error)")
        }
    }

    func update(startedAt: Date) async {
        guard let activity = currentActivity else { return }
        let newState = WorkoutActivityAttributes.ContentState(startedAt: startedAt)
        let newStaleDate = Calendar.current.date(byAdding: .hour, value: 3, to: Date())
        
        await activity.update(ActivityContent(state: newState, staleDate: newStaleDate))
    }

    func end(dismissalPolicy: ActivityUIDismissalPolicy = .after(Date().addingTimeInterval(1))) async {
        guard let activity = currentActivity else { return }
        await end(activity: activity, dismissalPolicy: dismissalPolicy)
        self.currentActivity = nil
    }

    private func end(activity: Activity<WorkoutActivityAttributes>,
                     dismissalPolicy: ActivityUIDismissalPolicy) async {
        let finalState = WorkoutActivityAttributes.ContentState(startedAt: activity.content.state.startedAt)
        let finalStaleDate = Calendar.current.date(byAdding: .hour, value: 3, to: Date())
        await activity.end(ActivityContent(state: finalState, staleDate: finalStaleDate),
                           dismissalPolicy: dismissalPolicy)
        print("Live Activity finalizada: \(activity.id)")
    }
}
