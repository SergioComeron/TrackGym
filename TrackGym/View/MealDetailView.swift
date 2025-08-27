import SwiftUI
import SwiftData
import HealthKit

//private let foodBySlug: [String: FoodSeed] = {
//    Dictionary(uniqueKeysWithValues: defaultFoods.map { ($0.slug, $0) })
//}()

struct MealDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var meal: Meal
    
    var body: some View {
        List {
            Section(header: Text("Alimentos en la comida")) {
                if meal.entries.isEmpty {
                    Text("Sin alimentos registrados.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(meal.entries) { entry in
                        HStack {
                            Text(foodName(for: entry.slug))
                                .font(.body)
                            Spacer()
                            Text("\(Int(entry.grams))g")
                                .foregroundStyle(.secondary)
                            if entry.protein > 0 {
                                Text("P: \(Int(entry.protein))")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                            if entry.carbs > 0 {
                                Text("C: \(Int(entry.carbs))")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                            if entry.fat > 0 {
                                Text("G: \(Int(entry.fat))")
                                    .font(.caption2)
                                    .foregroundStyle(.pink)
                            }
                        }
                    }
                    .onDelete(perform: deleteEntries)
                }
            }

            Section(header: Text("Totales de la comida")) {
                HStack(spacing: 12) {
                    Text("🍗 \(Int(meal.totalProtein))g P")
                    Text("🍚 \(Int(meal.totalCarbs))g C")
                    Text("🧈 \(Int(meal.totalFat))g G")
                    Text("🔥 \(Int(meal.totalKcal)) kcal")
                }.font(.caption)
            }
        }
        .navigationTitle(meal.type.rawValue.capitalized)
    }
    
    private let foodBySlug: [String: FoodSeed] = {
//        print("🔧 Creating foodBySlug dictionary with \(defaultFoods.count) foods")
        return Dictionary(uniqueKeysWithValues: defaultFoods.map { ($0.slug, $0) })
    }()

    private func foodName(for slug: String) -> String {
        foodBySlug[slug]?.name ?? slug
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            let entry = meal.entries[index]
            // Usamos el mismo syncId que se utilizó al guardar en HealthKit
//            let syncId: String = entry.entryUUID?.uuidString ?? "\(entry.slug)-\(Int(entry.grams))-\(Int(entry.date.timeIntervalSince1970))"
            let syncId: String = entry.entryUUID.uuidString
            print("[HK] 🗑️ Borrando por SyncIdentifier: \(syncId)")

            HealthKitManager.shared.deleteBySyncIdentifier(syncId) { success, count, error in
                if success {
                    print("✅ Borrado HK por SyncIdentifier: \(count) muestras para \(syncId)")
                } else {
                    print("❌ Error borrando HK por SyncIdentifier \(syncId): \(error?.localizedDescription ?? "?")")
                }
            }
            context.delete(entry)
        }
        meal.entries.remove(atOffsets: offsets)
        try? context.save()
    }
    
    
}

#Preview {
    let meal = Meal(date: .now, type: .comida)
    return MealDetailView(meal: meal)
        .modelContainer(for: [Meal.self, FoodLog.self], inMemory: true)
}
