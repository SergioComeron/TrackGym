import SwiftUI
import SwiftData

private let foodBySlug: [String: FoodSeed] = {
    Dictionary(uniqueKeysWithValues: defaultFoods.map { ($0.slug, $0) })
}()

struct AlimentacionView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Meal.date, order: .reverse)]) private var meals: [Meal]
    @State private var showingAddMeal = false
    @State private var showingAddFoodLogFor: Meal? = nil
    @State private var newMealType: MealType = .desayuno
    @State private var newMealDate: Date = Date()
    @State private var selectedFood: FoodSeed? = nil
    @State private var grams: Double = 100
    @State private var notes: String = ""
    @State private var selectedMeal: Meal? = nil

    var body: some View {
        NavigationStack {
            List {
                // Agrupa comidas por día descendente
                ForEach(groupedMealsByDay.keys.sorted(by: >), id: \.self) { day in
                    let mealsForDay = groupedMealsByDay[day] ?? []
                    let totalProtein = mealsForDay.reduce(0) { $0 + $1.totalProtein }
                    let totalCarbs   = mealsForDay.reduce(0) { $0 + $1.totalCarbs }
                    let totalFat     = mealsForDay.reduce(0) { $0 + $1.totalFat }
                    let totalKcal    = mealsForDay.reduce(0) { $0 + $1.totalKcal }

                    Section(header:
                        HStack {
                            Text(dayFormatted(day)).font(.headline)
                            Spacer()
                            Text("🍗 \(Int(totalProtein))g  🍚 \(Int(totalCarbs))g  🧈 \(Int(totalFat))g  🔥 \(Int(totalKcal)) kcal")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    ) {
                        ForEach(groupedMealsByDay[day] ?? []) { meal in
                            NavigationLink(destination: MealDetailView(meal: meal)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(meal.type.rawValue.capitalized)
                                            .font(.headline)
                                        Spacer()
                                        Text(timeFormatted(meal.date))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    // Totales
                                    HStack(spacing: 12) {
                                        Text("🍗 \(Int(meal.totalProtein))g P")
                                        Text("🍚 \(Int(meal.totalCarbs))g C")
                                        Text("🧈 \(Int(meal.totalFat))g G")
                                        Text("🔥 \(Int(meal.totalKcal)) kcal")
                                    }
                                    .font(.caption)
                                    // Entradas de comida
                                    if !meal.entries.isEmpty {
                                        VStack(alignment: .leading, spacing: 2) {
                                            ForEach(meal.entries) { entry in
                                                HStack {
                                                    Text(foodName(for: entry.slug))
                                                    Spacer(minLength: 8)
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
                                                .font(.caption)
                                            }
                                            .onDelete { offsets in
                                                deleteEntries(for: meal, at: offsets)
                                            }
                                        }.padding(.leading, 4)
                                    } else {
                                        Text("Sin alimentos registrados.")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete { offsets in
                            deleteMeals(for: day, at: offsets)
                        }
                    }
                }
            }
            .navigationTitle("Alimentación")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newMealType = .desayuno
                        newMealDate = Date()
                        showingAddMeal = true
                    } label: {
                        Label("Añadir comida", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddMeal) {
                NavigationStack {
                    Form {
                        Picker("Tipo", selection: $newMealType) {
                            ForEach(MealType.allCases, id: \.self) { t in
                                Text(t.rawValue.capitalized).tag(t)
                            }
                        }
                        DatePicker("Fecha y hora", selection: $newMealDate)
                    }
                    .navigationTitle("Nueva comida")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancelar") { showingAddMeal = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Guardar") {
                                let meal = Meal(date: newMealDate, type: newMealType)
                                context.insert(meal)
                                try? context.save()
                                showingAddMeal = false
                            }.disabled(newMealDate > Date().addingTimeInterval(60*5))
                        }
                    }
                }
            }
            .sheet(item: $showingAddFoodLogFor) { meal in
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
                                showingAddFoodLogFor = nil
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
                                showingAddFoodLogFor = nil
                            }
                            .disabled(selectedFood == nil || grams <= 0)
                        }
                    }
                }
            }
        }
    }

    // Helpers
    private var groupedMealsByDay: [Date: [Meal]] {
        Dictionary(grouping: meals) { $0.day }
    }
    private func dayFormatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }
    private func timeFormatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }
    private func foodName(for slug: String) -> String {
        foodBySlug[slug]?.name ?? slug
    }
    private func resetFoodLogFields() {
        selectedFood = nil
        grams = 100
        notes = ""
    }

    private func deleteMeals(for day: Date, at offsets: IndexSet) {
        let mealsForDay = groupedMealsByDay[day] ?? []
        for index in offsets {
            let meal = mealsForDay[index]
            context.delete(meal)
        }
        try? context.save()
    }

    private func deleteEntries(for meal: Meal, at offsets: IndexSet) {
        for index in offsets {
            let entry = meal.entries[index]
            context.delete(entry)
        }
        meal.entries.remove(atOffsets: offsets)
        try? context.save()
    }
}

#Preview {
    AlimentacionView()
        .modelContainer(for: [Meal.self, FoodLog.self], inMemory: true)
}
