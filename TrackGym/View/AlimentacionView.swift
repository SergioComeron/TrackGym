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
    @State private var useStandardServing: Bool = false
    
    @State private var showingFoodList = false
    @State private var searchText = ""
    
    // COMPUTED PROPERTY PARA FILTRAR ALIMENTOS
    var filteredFoods: [FoodSeed] {
        if searchText.isEmpty {
            return defaultFoods
        }
        return defaultFoods.filter { food in
            food.name.localizedCaseInsensitiveContains(searchText) ||
            food.desc.localizedCaseInsensitiveContains(searchText) ||
            food.category.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // MARK: - Helper Methods
    
    private var groupedMealsByDay: [Date: [Meal]] {
        Dictionary(grouping: meals) { $0.day }
    }
    
    private var timeSinceLastMeal: String {
        guard let lastMeal = meals.first else {
            return "Sin registro de comidas"
        }
        let interval = Date().timeIntervalSince(lastMeal.date)
        if interval < 0 {
            return "Sin registro de comidas"
        }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        var components: [String] = []
        if hours > 0 {
            components.append("\(hours)h")
        }
        if minutes > 0 || hours == 0 {
            components.append("\(minutes)m")
        }
        
        return "Hace " + components.joined(separator: " ") + " desde tu última comida"
    }
    
    private var timeSinceLastMealColor: Color {
        guard let lastMeal = meals.first else {
            return .gray
        }
        let interval = Date().timeIntervalSince(lastMeal.date)
        if interval >= 7200 {
            return .red
        } else if interval >= 0 && interval < 7200 {
            return .blue
        } else {
            return .gray
        }
    }

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
                                NavigationLink(destination: MealDetailView(meal: meal)) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        // Debug: mostrar si hay entradas sin exportar (opcional-safe)
                                        let unexported = meal.entriesOrEmpty.filter { $0.exportedToHealthKitAt == nil }.count
                                        // Header de la comida
                                        HStack {
                                            Text(meal.type.rawValue.capitalized)
                                                .font(.headline)
                                            Spacer()
                                            Text(timeFormatted(meal.date))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            if unexported > 0 {
                                                Text("⚠️\(unexported)")
                                                    .font(.caption2)
                                                    .foregroundStyle(.red)
                                            }
                                        }
                                        
                                        // Totales de macros
                                        HStack(spacing: 12) {
                                            Text("🍗 \(Int(meal.totalProtein))g P")
                                            Text("🍚 \(Int(meal.totalCarbs))g C")
                                            Text("🧈 \(Int(meal.totalFat))g G")
                                            Text("🔥 \(Int(meal.totalKcal)) kcal")
                                        }
                                        .font(.caption)
                                        
                                        // Lista de alimentos existentes (opcional-safe)
                                        if !meal.entriesOrEmpty.isEmpty {
                                            VStack(alignment: .leading, spacing: 2) {
                                                ForEach(meal.entriesOrEmpty) { entry in
                                                    HStack {
                                                        Text(foodName(for: entry.slug))
                                                        Spacer(minLength: 8)
                                                        Text("\(Int(entry.grams))g")
                                                            .foregroundStyle(.secondary)
                                                        let kcalValue = Int((foodBySlug[entry.slug]?.kcal ?? 0) * entry.grams / 100.0)
                                                        if kcalValue > 0 {
                                                            Text("K: \(kcalValue)")
                                                                .font(.caption2)
                                                                .foregroundStyle(.orange)
                                                        }
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
                                        
                                        // Botones en la misma fila: Añadir (izquierda) y Repetir (derecha)
                                        HStack(alignment: .center) {
                                            // Añadir alimento (izquierda)
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
                                            .controlSize(.regular)

                                            Spacer()

                                            // Repetir comida (derecha)
                                            Button {
                                                print("🔁 Repeat meal button pressed for: \(meal.type.rawValue) at \(meal.date)")
                                                repeatMeal(meal)
                                            } label: {
                                                HStack {
                                                    Image(systemName: "gobackward")
                                                    Text("Repetir comida")
                                                }
                                                .font(.subheadline)
                                            }
                                            .buttonStyle(.borderless)
                                            .controlSize(.regular)
                                            .disabled(meal.entriesOrEmpty.isEmpty)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
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
                    VStack(spacing: 0) {
                        Form {
                            // Sección de alimento seleccionado
                            if let selectedFood = selectedFood {
                                Section("Alimento seleccionado") {
                                    HStack {
                                        // Icono del alimento
                                        Image(systemName: foodIcon(for: selectedFood.category))
                                            .foregroundColor(iconColor(for: selectedFood.category))
                                            .font(.title2)
                                            .frame(width: 30)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(selectedFood.name)
                                                .font(.headline)
                                            Text(selectedFood.desc)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                            
                                            Text(selectedFood.category.rawValue)
                                                .font(.caption2)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(iconColor(for: selectedFood.category).opacity(0.2))
                                                .foregroundColor(iconColor(for: selectedFood.category))
                                                .cornerRadius(4)
                                        }
                                        
                                        Spacer()
                                        
                                        Button("Cambiar") {
                                            showingFoodList = true
                                        }
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    }
                                    .contentShape(Rectangle())
                                }
                            } else {
                                Section("Seleccionar alimento") {
                                    Button(action: { showingFoodList = true }) {
                                        HStack {
                                            Image(systemName: "magnifyingglass")
                                                .foregroundColor(.blue)
                                            Text("Buscar y seleccionar alimento")
                                                .foregroundColor(.blue)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.secondary)
                                                .font(.caption)
                                        }
                                    }
                                }
                            }
                            
                            // Cantidad (con soporte de ración estándar si existe)
                            Section("Cantidad") {
                                if let f = selectedFood, let g = defaultGrams(for: f.slug) {
                                    Toggle("Usar ración estándar (\(Int(g)) g)", isOn: $useStandardServing)
                                        .onChange(of: useStandardServing) { _, on in
                                            if on { grams = g }
                                        }

                                    HStack {
                                        Text("Gramos")
                                        Spacer()
                                        TextField("0", value: $grams, formatter: NumberFormatter())
                                            .keyboardType(.decimalPad)
                                            .frame(width: 80)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .multilineTextAlignment(.center)
                                            .disabled(useStandardServing)
                                    }
                                } else {
                                    HStack {
                                        Text("Gramos")
                                        Spacer()
                                        TextField("0", value: $grams, formatter: NumberFormatter())
                                            .keyboardType(.decimalPad)
                                            .frame(width: 80)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .multilineTextAlignment(.center)
                                    }
                                }
                            }
                            
                            // Información nutricional calculada
                            if let selectedFood = selectedFood, grams > 0 {
                                Section("Información nutricional") {
                                    NutritionalInfoGrid(food: selectedFood, grams: grams)
                                }
                            }
                            
                            // Notas
                            Section("Notas (opcional)") {
                                TextField("Añade alguna nota...", text: $notes, axis: .vertical)
                                    .lineLimit(2...4)
                            }
                        }
                    }
                    .navigationTitle("Añadir alimento")
                    .navigationBarTitleDisplayMode(.inline)
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
                                
                                // Tu código de guardado existente...
                                let entry = FoodLog(date: meal.date, slug: food.slug, grams: grams, notes: notes, meal: meal)
                                context.insert(entry)
                                if meal.entries == nil {
                                    meal.entries = []
                                }
                                meal.entries?.append(entry)
                                do {
                                    try context.save()
                                    print("✅ CoreData save successful")
                                } catch {
                                    print("❌ CoreData save failed: \(error)")
                                    return
                                }
                                
                                print("🎯 About to call exportEntryDirectly")
                                exportEntryDirectly(entry, food: food)
                                print("🎯 exportEntryDirectly called")
                                
                                resetFoodLogFields()
                                showingAddFoodLogFor = nil
                                print("📱 Sheet closed")
                            }
                            .disabled(selectedFood == nil || grams <= 0)
                        }
                    }
                    .onChange(of: selectedFood) { _, newValue in
                        if let f = newValue, let g = defaultGrams(for: f.slug) {
                            useStandardServing = true
                            grams = g
                        } else {
                            useStandardServing = false
                        }
                    }
                    .sheet(isPresented: $showingFoodList) {
                        FoodSelectionView(
                            foods: filteredFoods,
                            selectedFood: $selectedFood,
                            searchText: $searchText
                        )
                    }
                }
            }
        }
        .overlay(
            HStack {
                Spacer()
                HStack {
                    Image(systemName: "clock.fill")
            
                    Text(timeSinceLastMeal)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.clear.tint(timeSinceLastMealColor))
                Spacer()
            }
            .padding(.bottom, 32)
            , alignment: .bottom
            
        )
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
    
    // FUNCIONES HELPER PARA ICONOS Y COLORES
    func foodIcon(for category: FoodCategory) -> String {
        switch category {
        case .protein:
            return "fish.fill"
        case .carb:
            return "leaf.fill"
        case .fat:
            return "drop.triangle.fill"
        case .vegetable:
            return "carrot.fill"
        case .fruit:
            return "apple.logo"
        case .dairy:
            return "drop.fill"
        case .beverage:
            return "cup.and.saucer.fill"
        case .misc:
            return "fork.knife"
        }
    }

    func iconColor(for category: FoodCategory) -> Color {
        switch category {
        case .protein:
            return .brown
        case .carb:
            return .orange
        case .fat:
            return .yellow
        case .vegetable:
            return .green
        case .fruit:
            return .red
        case .dairy:
            return .blue
        case .beverage:
            return .cyan
        case .misc:
            return .primary
        }
    }

    // MARK: - HealthKit Export Methods
    
    /// ✅ Exporta directamente usando la nueva firma con metadata (SyncIdentifier/Version)
    private func exportEntryDirectly(_ entry: FoodLog, food: FoodSeed) {
        // Calcular macros
        let multiplier = entry.grams / 100.0
        let protein = food.protein * multiplier
        let carbs = food.carbs * multiplier
        let fat = food.fat * multiplier
        let kcal = food.kcal * multiplier

        // Nombre visible en Salud + clave única técnica
        let foodName = "\(food.name) (\(Int(entry.grams))-\(entry.date.timeIntervalSince1970)g)"
        let syncId = entry.entryUUID.uuidString

        print(">>>Se crea: \(foodName)")
        print("🚀 DIRECT EXPORT: \(foodName)")
        print("📊 Values: P:\(protein)g C:\(carbs)g F:\(fat)g K:\(kcal)kcal")

        // Metadata recomendado por Apple para identificar/borrar
        let metadata: [String: Any] = [
            HKMetadataKeyFoodType: foodName,
            HKMetadataKeySyncIdentifier: syncId,
            HKMetadataKeySyncVersion: 1
        ]

        // Guardar correlación .food + 4 samples con el MISMO metadata
        HealthKitManager.shared.saveMealAsFoodCorrelation(
            date: entry.date,
            name: foodName,
            protein: protein,
            carbs: carbs,
            fat: fat,
            kcal: kcal,
            metadata: metadata,
            completion: { success, uuid, error in
                print("🔄 HealthKit callback received: success=\(success)")
                if let error = error {
                    print("❌ HealthKit error: \(error.localizedDescription)")
                }

                DispatchQueue.main.async {
                    if success {
                        print("✅ DIRECT EXPORT SUCCESS!")
                        entry.exportedToHealthKitAt = Date()
                        entry.healthKitUUID = uuid
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
        )
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
        ) { success, uuid, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Successfully exported complete meal to HealthKit")
                    let now = Date()
                    for entry in meal.entriesOrEmpty {
                        entry.exportedToHealthKitAt = now
                        // Asegúrate de que FoodLog tiene la propiedad healthKitUUID: UUID?
                        entry.healthKitUUID = uuid
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
            let entry = meal.entriesOrEmpty[index]
            context.delete(entry)
        }
        var current = meal.entries ?? []
        current.remove(atOffsets: offsets)
        meal.entries = current
        try? context.save()
    }

    // MARK: - Repeat Meal
    private func repeatMeal(_ original: Meal) {
        let now = Date()
        // Crear nueva comida con el mismo tipo, en la fecha actual
        let newMeal = Meal(date: now, type: original.type)
        context.insert(newMeal)

        // Copiar todas las entradas (alimentos) con las mismas cantidades
        for oldEntry in original.entriesOrEmpty {
            let newEntry = FoodLog(
                date: now,
                slug: oldEntry.slug,
                grams: oldEntry.grams,
                notes: oldEntry.notes,
                meal: newMeal
            )
            context.insert(newEntry)
            if newMeal.entries == nil { newMeal.entries = [] }
            newMeal.entries?.append(newEntry)
            
            // Exportar a HealthKit como en el alta manual
            if let seed = foodBySlug[oldEntry.slug] {
                exportEntryDirectly(newEntry, food: seed)
            } else {
                print("⚠️ No FoodSeed found for slug: \(oldEntry.slug), skipping HK export")
            }
        }

        do {
            try context.save()
            print("✅ Meal repeated successfully with \(newMeal.entriesOrEmpty.count) entries")
        } catch {
            print("❌ Error repeating meal: \(error)")
        }
    }
}



struct FoodSelectionView: View {
    let foods: [FoodSeed]
    @Binding var selectedFood: FoodSeed?
    @Binding var searchText: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Barra de búsqueda
                SearchBar(text: $searchText)
                    .padding()
                
                List {
                    // Agrupados por categoría
                    ForEach(groupedFoods.keys.sorted { $0.rawValue < $1.rawValue }, id: \.self) { category in
                        Section(category.rawValue) {
                            ForEach(groupedFoods[category] ?? [], id: \.slug) { food in
                                FoodRowView(
                                    food: food,
                                    isSelected: selectedFood?.slug == food.slug
                                ) {
                                    selectedFood = food
                                    dismiss()
                                }
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Seleccionar alimento")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                // Botón para limpiar selección si hay una
                if selectedFood != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Limpiar") {
                            selectedFood = nil
                            dismiss()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    private var groupedFoods: [FoodCategory: [FoodSeed]] {
        Dictionary(grouping: foods) { $0.category }
    }
}

extension Meal {
    /// Devuelve siempre un array (vacío si `entries` es nil)
    var entriesOrEmpty: [FoodLog] {
        entries ?? []
    }
}

// ROW DE ALIMENTO MEJORADA
struct FoodRowView: View {
    let food: FoodSeed
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icono de categoría
            Image(systemName: foodIcon(for: food.category))
                .foregroundColor(iconColor(for: food.category))
                .font(.title2)
                .frame(width: 35, height: 35)
                .background(iconColor(for: food.category).opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(food.desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Información nutricional compacta
                HStack(spacing: 16) {
                    NutrientBadge(
                        value: Int(food.kcal),
                        unit: "kcal",
                        color: .orange,
                        icon: "flame.fill"
                    )
                    
                    NutrientBadge(
                        value: food.protein,
                        unit: "P",
                        color: .blue,
                        icon: "p.circle.fill"
                    )
                    
                    NutrientBadge(
                        value: food.carbs,
                        unit: "C",
                        color: .green,
                        icon: "c.circle.fill"
                    )
                    
                    NutrientBadge(
                        value: food.fat,
                        unit: "G",
                        color: .yellow,
                        icon: "f.circle.fill"
                    )
                    
                    Spacer()
                }
                .padding(.top, 2)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .padding(.vertical, 4)
    }
    
    // FUNCIONES HELPER GLOBALES (disponibles para todos los componentes)
    func foodIcon(for category: FoodCategory) -> String {
        switch category {
        case .protein:
            return "fish.fill"
        case .carb:
            return "leaf.fill"
        case .fat:
            return "drop.triangle.fill"
        case .vegetable:
            return "carrot.fill"
        case .fruit:
            return "apple.logo"
        case .dairy:
            return "drop.fill"
        case .beverage:
            return "cup.and.saucer.fill"
        case .misc:
            return "fork.knife"
        }
    }

    func iconColor(for category: FoodCategory) -> Color {
        switch category {
        case .protein:
            return .brown
        case .carb:
            return .orange
        case .fat:
            return .yellow
        case .vegetable:
            return .green
        case .fruit:
            return .red
        case .dairy:
            return .blue
        case .beverage:
            return .cyan
        case .misc:
            return .primary
        }
    }
}

// COMPONENTE PARA BADGES DE NUTRIENTES
struct NutrientBadge: View {
    let value: Double
    let unit: String
    let color: Color
    let icon: String
    
    init(value: Double, unit: String, color: Color, icon: String) {
        self.value = value
        self.unit = unit
        self.color = color
        self.icon = icon
    }
    
    init(value: Int, unit: String, color: Color, icon: String) {
        self.value = Double(value)
        self.unit = unit
        self.color = color
        self.icon = icon
    }
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
            Text(formattedValue)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
    }
    
    private var formattedValue: String {
        if unit == "kcal" {
            return "\(Int(value))"
        } else {
            return String(format: "%.1f", value)
        }
    }
    
    
    
}

// GRID DE INFORMACIÓN NUTRICIONAL
struct NutritionalInfoGrid: View {
    let food: FoodSeed
    let grams: Double
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            NutritionalInfoCard(
                title: "Calorías",
                value: String(format: "%.0f", food.kcal * grams / 100),
                unit: "kcal",
                color: .orange,
                icon: "flame.fill"
            )
            
            NutritionalInfoCard(
                title: "Proteínas",
                value: String(format: "%.1f", food.protein * grams / 100),
                unit: "g",
                color: .blue,
                icon: "p.circle.fill"
            )
            
            NutritionalInfoCard(
                title: "Carbohidratos",
                value: String(format: "%.1f", food.carbs * grams / 100),
                unit: "g",
                color: .green,
                icon: "c.circle.fill"
            )
            
            NutritionalInfoCard(
                title: "Grasas",
                value: String(format: "%.1f", food.fat * grams / 100),
                unit: "g",
                color: .yellow,
                icon: "f.circle.fill"
            )
        }
    }
}

// CARD DE INFORMACIÓN NUTRICIONAL
struct NutritionalInfoCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            HStack {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// BARRA DE BÚSQUEDA
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Buscar alimentos...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}




#Preview {
    AlimentacionView()
        .modelContainer(for: [Meal.self, FoodLog.self], inMemory: true)
}

/// Helper to get default grams for a food slug (returns Double? or nil if not found)
//private func defaultGrams(for slug: String) -> Double? {
//    foodBySlug[slug]?.defaultServingGrams
//}
