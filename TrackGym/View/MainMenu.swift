//
//  ContentView.swift
//  TrackGym
//
//  Created by Sergio Comerón on 17/8/25.
//

import SwiftUI

struct MainMenu: View {
    var body: some View {
        TabView {
            NavigationStack {
                EntrenamientoListView()
                    .navigationTitle("Entrenos")
            }
            .tabItem {
                Label("Entrenos", systemImage: "dumbbell")
            }

            NavigationStack {
                Text("Progreso")
                    .navigationTitle("Progreso")
            }
            .tabItem {
                Label("Progreso", systemImage: "chart.bar.fill")
            }

            NavigationStack {
                Text("Perfil")
                    .navigationTitle("Perfil")
            }
            .tabItem {
                Label("Perfil", systemImage: "person.fill")
            }
        }
    }
}

#Preview {
    MainMenu()
}
