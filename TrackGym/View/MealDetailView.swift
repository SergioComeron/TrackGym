import SwiftUI
import SwiftData

private let foodBySlug: [String: FoodSeed] = {
    Dictionary(uniqueKeysWithValues: defaultFoods.map { ($0.slug, $0) })
}()

struct MealDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var meal: Meal
    @State private var showingAddFood = false
    @State private var selectedFood: FoodSeed? = nil
    @State private var grams: Double = 100
    @State private var notes: String = ""

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddFood = true
                } label: {
                    Label("Añadir alimento", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddFood) {
            NavigationStack {
                Form {
                    Picker("Alimento", selection: Binding(get: {
                        selectedFood ?? defaultFoods.first
                    }, set: { newValue in
                        selectedFood = newValue
                    })) {
                        ForEach(defaultFoods, id: \.slug) { food in
                            Text(food.name).tag(food as FoodSeed?)
                        }
                    }
                    HStack {
                        Text("Cantidad (g)")
                        Spacer()
                        TextField("g", value: $grams, formatter: NumberFormatter())
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                    }
                    TextField("Notas", text: $notes)
                }
                .navigationTitle("Añadir alimento")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") {
                            resetFoodLogFields()
                            showingAddFood = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Guardar") {
                            guard let food = selectedFood else { return }
                            let entry = FoodLog(date: Date(), slug: food.slug, grams: grams, notes: notes, meal: meal)
                            context.insert(entry)
                            meal.entries.append(entry)
                            try? context.save()
                            resetFoodLogFields()
                            showingAddFood = false
                        }
                        .disabled(selectedFood == nil || grams <= 0)
                    }
                }
            }
        }
    }

    private func foodName(for slug: String) -> String {
        foodBySlug[slug]?.name ?? slug
    }
    private func resetFoodLogFields() {
        selectedFood = nil
        grams = 100
        notes = ""
    }
    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            let entry = meal.entries[index]
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
