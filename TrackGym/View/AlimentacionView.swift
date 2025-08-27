import SwiftUI
import SwiftData
import HealthKit

// ✅ Descomentado y corregido - movido fuera para evitar recreaciones constantes
private let foodBySlug: [String: FoodSeed] = Dictionary(uniqueKeysWithValues: defaultFoods.map { ($0.slug, $0) })

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
                            VStack(alignment: .leading, spacing: 8) {
                                // Header de la comida
                                HStack {
                                    Text(meal.type.rawValue.capitalized)
                                        .font(.headline)
                                    Spacer()
                                    Text(timeFormatted(meal.date))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    // Debug: mostrar si hay entradas sin exportar
                                    let unexported = meal.entries.filter { $0.exportedToHealthKitAt == nil }.count
                                    if unexported > 0 {
                                        Text("⚠️\(unexported)")
                                            .font(.caption2)
                                            .foregroundStyle(.red)
                                    }
                                }
                                
                                // Botón para añadir alimentos - FUERA del NavigationLink
                                Button {
                                    print("🍎 Add food button pressed for meal: \(meal.type.rawValue)")
                                    selectedMeal = meal
                                    showingAddFoodLogFor = meal
                                } label: {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Añadir alimento")
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                                }
                                .buttonStyle(.borderless)
                                
                                // Totales de macros
                                HStack(spacing: 12) {
                                    Text("🍗 \(Int(meal.totalProtein))g P")
                                    Text("🍚 \(Int(meal.totalCarbs))g C")
                                    Text("🧈 \(Int(meal.totalFat))g G")
                                    Text("🔥 \(Int(meal.totalKcal)) kcal")
                                }
                                .font(.caption)
                                
                                // Lista de alimentos existentes
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
                                    }
                                    .padding(.leading, 4)
                                } else {
                                    Text("Sin alimentos registrados.")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
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
                        print("➕ Add meal button pressed")
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
                                print("💾 Creating meal...")
                                let meal = Meal(date: newMealDate, type: newMealType)
                                context.insert(meal)
                                do {
                                    try context.save()
                                    print("✅ Meal created successfully")
                                } catch {
                                    print("❌ Error creating meal: \(error)")
                                }
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
                                guard let food = selectedFood else {
                                    print("❌ No food selected")
                                    return
                                }
                                
                                print("💾 STARTING SAVE PROCESS")
                                print("📝 Food: \(food.name), Grams: \(grams)")
                                
                                // Crear la entrada
                                let entry = FoodLog(date: Date(), slug: food.slug, grams: grams, notes: notes, meal: meal)
                                context.insert(entry)
                                meal.entries.append(entry)
                                
                                // Guardar en CoreData
                                do {
                                    try context.save()
                                    print("✅ CoreData save successful")
                                } catch {
                                    print("❌ CoreData save failed: \(error)")
                                    return
                                }
                                
                                // EXPORTAR INMEDIATAMENTE - ANTES de cerrar el sheet
                                print("🎯 About to call exportEntryDirectly")
                                exportEntryDirectly(entry, food: food)
                                print("🎯 exportEntryDirectly called")
                                
                                // Pequeño delay para que termine la exportación antes de cerrar
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    resetFoodLogFields()
                                    showingAddFoodLogFor = nil
                                    print("📱 Sheet closed")
                                }
                            }
                            .disabled(selectedFood == nil || grams <= 0)
                        }
                    }
                }
            }
        }
        .onAppear {
            HealthKitManager.shared.requestAuthorization { success, error in
                if success {
                    print("✅ HealthKit authorization successful")
                    HealthKitManager.shared.enableBackgroundDeliveryForNutrition(frequency: .immediate) { ok, err in
                        if !ok { print("❌ Enable BG delivery failed: \(err?.localizedDescription ?? "?")") }
                        else { print("✅ Background delivery enabled") }
                    }
                    HealthKitManager.shared.startNutritionObservers { identifier in
                        print("[HK] 📊 Update delivered for: \(identifier.rawValue)")
                    }
                } else {
                    print("❌ HealthKit auth failed: \(error?.localizedDescription ?? "?")")
                }
            }
        }
    }

    // MARK: - Helper Methods
    
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
        return foodBySlug[slug]?.name ?? "Alimento desconocido (\(slug))"
    }
    
    private func resetFoodLogFields() {
        selectedFood = nil
        grams = 100
        notes = ""
    }

    // MARK: - HealthKit Export Methods
    
    /// ✅ Exporta directamente usando la función que ya sabemos que funciona
    private func exportEntryDirectly(_ entry: FoodLog, food: FoodSeed) {
        // Calcular macros
        let multiplier = entry.grams / 100.0
        let protein = food.protein * multiplier
        let carbs = food.carbs * multiplier
        let fat = food.fat * multiplier
        let kcal = food.kcal * multiplier
        
        let foodName = "\(food.name) (\(Int(entry.grams))g)"
        
        print("🚀 DIRECT EXPORT: \(foodName)")
        print("📊 Values: P:\(protein)g C:\(carbs)g F:\(fat)g K:\(kcal)kcal")
        
        // Usar la función que YA sabemos que funciona con el gesto
        HealthKitManager.shared.saveMealAsFoodCorrelation(
            date: entry.date,
            name: foodName,
            protein: protein,
            carbs: carbs,
            fat: fat,
            kcal: kcal
        ) { success, error in
            print("🔄 HealthKit callback received: success=\(success)")
            if let error = error {
                print("❌ HealthKit error: \(error.localizedDescription)")
            }
            
            DispatchQueue.main.async {
                if success {
                    print("✅ DIRECT EXPORT SUCCESS!")
                    entry.exportedToHealthKitAt = Date()
                    do {
                        try context.save()
                        print("✅ Timestamp saved")
                    } catch {
                        print("❌ Error saving timestamp: \(error)")
                    }
                } else {
                    print("❌ DIRECT EXPORT FAILED: \(error?.localizedDescription ?? "Unknown")")
                }
            }
        }
    }
    
    /// ✅ Versión async mantenida solo como backup si es necesaria
    private func exportEntryImmediately(_ entry: FoodLog, food: FoodSeed) async {
        // Calcular macros
        let multiplier = entry.grams / 100.0
        let protein = food.protein * multiplier
        let carbs = food.carbs * multiplier
        let fat = food.fat * multiplier
        let kcal = food.kcal * multiplier
        
        print("🚀 Exporting food entry: \(food.name) (\(entry.grams)g)")
        
        // Usar continuation para convertir callback a async
        let result = await withCheckedContinuation { continuation in
            HealthKitManager.shared.saveFoodEntry(
                date: entry.date,
                foodName: food.name,
                grams: entry.grams,
                protein: protein,
                carbs: carbs,
                fat: fat,
                kcal: kcal
            ) { success, error in
                continuation.resume(returning: (success, error))
            }
        }
        
        // Actualizar en main thread
        await MainActor.run {
            if result.0 {
                print("✅ SUCCESS: Food entry saved to HealthKit")
                entry.exportedToHealthKitAt = Date()
                do {
                    try context.save()
                    print("✅ Export timestamp updated")
                } catch {
                    print("❌ Error updating timestamp: \(error)")
                }
            } else {
                print("❌ FAILED: Could not save food entry: \(result.1?.localizedDescription ?? "Unknown error")")
                // Marcar como no exportado para retry
                entry.exportedToHealthKitAt = nil
            }
        }
    }
    
    /// ✅ Método legacy mantenido solo para compatibilidad (ya no se usa)
    private func exportNewEntryToHealthKit(_ entry: FoodLog, for meal: Meal) {
        guard let food = foodBySlug[entry.slug] else {
            print("❌ Food not found for slug: \(entry.slug)")
            return
        }
        
        exportEntryDirectly(entry, food: food)
    }

    /// ✅ Método eliminado - ya no es necesario
    private func closeMealAndExportDelta(_ meal: Meal) {
        print("ℹ️ closeMealAndExportDelta called but no longer needed - all exports should be automatic")
    }

    /// ✅ Exporta una comida completa (usado como fallback si es necesario)
    private func exportMealToHealthKit(_ meal: Meal) {
        print("🍽️ Exporting complete meal: \(meal.type.rawValue)")
        print("📊 Totals: P:\(meal.totalProtein)g C:\(meal.totalCarbs)g F:\(meal.totalFat)g K:\(meal.totalKcal)kcal")
        
        let name = meal.type.rawValue.capitalized
        HealthKitManager.shared.saveMealAsFoodCorrelation(
            date: meal.date,
            name: name,
            protein: meal.totalProtein,
            carbs: meal.totalCarbs,
            fat: meal.totalFat,
            kcal: meal.totalKcal
        ) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Successfully exported complete meal to HealthKit")
                    let now = Date()
                    for entry in meal.entries {
                        entry.exportedToHealthKitAt = now
                    }
                    try? context.save()
                } else {
                    print("❌ HK export failed: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }

    // MARK: - Delete Methods
    
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
