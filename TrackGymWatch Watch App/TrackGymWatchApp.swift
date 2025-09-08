//
//  TrackGymWatchApp.swift
//  TrackGymWatch Watch App
//
//  Created by Sergio Comerón on 8/9/25.
//

import SwiftUI
import SwiftData

@main
struct TrackGymWatch_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(createModelContainer())
    }
}

private func createModelContainer() -> ModelContainer {
    let schema = Schema([
        Entrenamiento.self,
        PerformedExercise.self,
        ExerciseSet.self,
    ])
    let modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        cloudKitDatabase: .automatic
    )
    do {
        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        print("ModelContainer created successfully for Watch App.")
        return container
    } catch {
        print("Failed to create ModelContainer for Watch App: \\(error)")
        fatalError("Could not create ModelContainer: \\(error)")
    }
}
