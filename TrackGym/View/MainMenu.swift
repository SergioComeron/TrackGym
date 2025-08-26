//
//  ContentView.swift
//  TrackGym
//
//  Created by Sergio Comerón on 17/8/25.
//

import SwiftUI
import SwiftData

private struct EntrenosTab: View {
    @Environment(Router.self) private var router
    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.entrenosPath) {
            EntrenamientoListView()
                .navigationTitle("Entrenos")
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .entrenamientoDetail(let id):
                        EntrenamientoDetailLoaderView(entrenamientoID: id)
                    }
                }
        }
        .onChange(of: router.pendingEntrenamientoID, initial: true) { oldValue, newValue in
            if let id = newValue {
                print("🧭 onChange pendingEntrenamientoID (old: \(String(describing: oldValue)) -> new: \(id)) — empujamos en siguiente ciclo")
                DispatchQueue.main.async {
                    router.entrenosPath = [.entrenamientoDetail(id)]
                    router.pendingEntrenamientoID = nil
                }
            }
        }
    }
}

struct MainMenu: View {
    @Environment(Router.self) private var router
    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            EntrenosTab()
                .tabItem { Label("Entrenos", systemImage: "dumbbell") }
                .tag(Router.Tab.entrenos)

            NavigationStack {
                ProgresoView()
            }
            .tabItem { Label("Progreso", systemImage: "chart.bar.fill") }
            .tag(Router.Tab.progreso)

            DietaView()
                .tabItem { Label("Dieta", systemImage: "fork.knife") }
                .tag(Router.Tab.dieta)

            NavigationStack {
                PerfilView()
            }
            .tabItem { Label("Perfil", systemImage: "person.fill") }
            .tag(Router.Tab.perfil)
        }
    }
}

#Preview {
    MainMenu()
}
