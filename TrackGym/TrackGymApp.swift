import SwiftUI
import SwiftData
import Observation

enum AppRoute: Hashable {
    case entrenamientoDetail(UUID)
}

@Observable
final class Router {
    enum Tab: Hashable { case entrenos, progreso, alimentacion, perfil }
    var selectedTab: Tab = .progreso
    var entrenosPath: [AppRoute] = []
    var pendingEntrenamientoID: UUID?
}

@main
struct TrackGymApp: App {
    @State private var router = Router()

    var body: some Scene {
        WindowGroup {
            MainMenu()
                .environment(router)
                .onOpenURL { url in
                    print("Abrí la app con URL:", url)

                    guard url.scheme == "trackgym" else { return }
                    if url.host == "live-activity" {
                        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
                           let idString = comps.queryItems?.first(where: { $0.name == "entrenamiento" })?.value,
                           let id = UUID(uuidString: idString) {

                            print("📩 Deep link recibido con id:", id)
                            router.selectedTab = .entrenos

                            // 👇 Deferimos la entrega del ID para que el NavigationStack ya exista
                            DispatchQueue.main.async {
                                router.pendingEntrenamientoID = id
                            }
                        }
                    }
                }
        }
        .modelContainer(createModelContainer())
    }
    
    // MARK: - CloudKit Configuration
    private func createModelContainer() -> ModelContainer {
        let schema = Schema([
            Entrenamiento.self,
            PerformedExercise.self,
            ExerciseSet.self,
            Perfil.self,
            FoodLog.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic  // 👈 Esto es clave para CloudKit
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Opcional: Log para debug
            print("✅ ModelContainer creado exitosamente con CloudKit")
            
            return container
        } catch {
            print("❌ Error creando ModelContainer: \(error)")
            fatalError("No se pudo crear el ModelContainer: \(error)")
        }
    }
}

struct EntrenamientoDetailLoaderView: View {
    @Environment(\.modelContext) private var context
    let entrenamientoID: UUID

    @State private var entrenamiento: Entrenamiento?

    var body: some View {
        Group {
            if let e = entrenamiento {
                EntrenamientoDetailView(entrenamiento: e)
            } else {
                ProgressView("Cargando…")
                    .task { await load() }
            }
        }
        .navigationTitle("Entrenamiento")
    }

    private func load() async {
        do {
            print("🔎 Buscando entrenamiento con id:", entrenamientoID)

            let descriptor = FetchDescriptor<Entrenamiento>(
                predicate: #Predicate { $0.id == entrenamientoID },
                sortBy: []
            )

            let results = try context.fetch(descriptor)
            print("📊 Resultados encontrados:", results.count)

            if let first = results.first {
                print("✅ Entrenamiento encontrado:", first)
                entrenamiento = first
            } else {
                print("❌ No se encontró ningún entrenamiento con ese ID")
            }
        } catch {
            print("⚠️ Error cargando entrenamiento:", error)
        }
    }
}
