//
//  TrackGymApp.swift
//  TrackGym
//
//  Created by Sergio Comerón on 17/8/25.
//

import SwiftUI
import SwiftData

@main
struct TrackGymApp: App {
    var body: some Scene {
        WindowGroup {
            MainMenu()
        }
        .modelContainer(for: [Entrenamiento.self])
    }
}
