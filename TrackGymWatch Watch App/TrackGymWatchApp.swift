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
//    var sharedModelContainer: ModelContainer = {
//        let schema = Schema([
//            Entrenamiento.self,
//            PerformedExercise.self,
//            ExerciseSet.self,
//        ])
//        
//        let modelConfiguration = ModelConfiguration(
//            schema: schema,
//            isStoredInMemoryOnly: false,
//            cloudKitDatabase: .automatic  // 👈 ¡Esto es lo que faltaba!
//        )
//
//        do {
//            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
//            print("✅ Watch ModelContainer creado con CloudKit")
//            return container
//        } catch {
//            print("❌ Error creando Watch ModelContainer: \(error)")
//            fatalError("Could not create ModelContainer: \(error)")
//        }
//    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
//        .modelContainer(sharedModelContainer)
        .modelContainer(for: [Entrenamiento.self, PerformedExercise.self, ExerciseSet.self])
    }
}
