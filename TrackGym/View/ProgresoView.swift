//  ProgresoView.swift
//  TrackGym
//  Visualización de progreso de entrenamientos

import SwiftUI
import SwiftData
import FoundationModels
import HealthKit
#if canImport(Charts)
import Charts
#endif

struct ProgresoView: View {
    @State private var healthKitAuthorized = false
    @State private var requestingPermissions = false
    
    @Query(sort: [SortDescriptor(\Entrenamiento.startDate, order: .reverse)])
    private var entrenamientos: [Entrenamiento]
    
    @Query private var perfiles: [Perfil]
    
    @Query private var meals: [Meal]
    
    @State private var selectedSlug: String? = nil
    @State private var resumenEntrenoHoy: String? = nil
    @State private var cargandoResumenEntrenoHoy = false
    @State private var lastResumenEntrenoID: UUID? = nil
    
    @State private var resumenSemana: String? = nil
    @State private var cargandoResumenSemana = false
    
    @State private var burnedCaloriesHK: Double = 0
    @State private var consumedCalories: Double = 0
    
    // NUEVO: macros reales del periodo
    @State private var proteinReal: Double = 0
    @State private var carbsReal: Double = 0
    @State private var fatReal: Double = 0
    @State private var kcalReal: Double = 0
    
    // NUEVO: objetivos (targets) calculados
    @State private var calTarget: Double = 0
    @State private var proteinTarget: Double = 0
    @State private var fatTarget: Double = 0
    @State private var carbsTarget: Double = 0
    
    @State private var periodoSeleccionado: PeriodoCalorias = .hoy

    private let resumenEntrenoKey = "ResumenEntrenoHoy"
    private let resumenEntrenoIDKey = "LastResumenEntrenoID"
    private let resumenSemanaKey = "ResumenSemanaAI"
    private let resumenSemanaDateKey = "FechaResumenSemanaAI"

    enum PeriodoCalorias: String, CaseIterable, Identifiable {
        case hoy = "Hoy"
        case semana = "Semana"
        case mes = "Mes"
        
        var id: String { self.rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                
                Label("Comparación calorías", systemImage: "chart.pie.fill")
                    .font(.headline)
                    .padding(.bottom, 2)
                
                Picker("Periodo", selection: $periodoSeleccionado) {
                    ForEach(PeriodoCalorias.allCases) { periodo in
                        Text(periodo.rawValue).tag(periodo)
                    }
                }
                .pickerStyle(.segmented)
                
                let diff = consumedCalories - burnedCaloriesHK

                VStack(spacing: 8) {
                    // Cabecera con totales
                    HStack(spacing: 12) {
                        VStack(alignment: .leading) {
                            Text("Consumidas").font(.caption)
                            Text("\(Int(consumedCalories)) kcal")
                                .font(.title3).bold().foregroundColor(.orange)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Gastadas").font(.caption)
                            Text("\(Int(burnedCaloriesHK)) kcal")
                                .font(.title3).bold().foregroundColor(.blue)
                        }
                    }
                    .padding(.bottom, 6)

                    // Gráfico oficial de Charts (sustituye las barras "artesanales")
                    #if canImport(Charts)
                    let chartData: [(String, Double)] = [("Consumidas", consumedCalories), ("Gastadas", burnedCaloriesHK)]
                    Chart(chartData, id: \.0) { item in
                        BarMark(
                            x: .value("Tipo", item.0),
                            y: .value("kcal", item.1)
                        )
                        .foregroundStyle(by: .value("Tipo", item.0))
                        .annotation(position: .top) {
                            Text("\(Int(item.1))")
                                .font(.caption2)
                        }
                    }
                    .chartYAxisLabel("kcal", position: .trailing, alignment: .center)
                    .chartLegend(.visible)
                    .frame(height: 180)
                    .animation(.easeInOut, value: consumedCalories)
                    .animation(.easeInOut, value: burnedCaloriesHK)
                    #else
                    // Fallback si Charts no está disponible (opcional: deja vacío)
                    EmptyView()
                    #endif
                    
                    Text("Incluye metabolismo basal y actividad física (HealthKit)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }

                Text(diff >= 0 ? "Superávit calórico: +\(Int(diff)) kcal" : "Déficit calórico: \(Int(diff)) kcal")
                    .foregroundColor(diff >= 0 ? .red : .green)
                    .font(.callout)
                    .padding(.top, 4)

                if burnedCaloriesHK == 0 {
                    if requestingPermissions {
                        Text("Solicitando permisos de Salud...")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    } else if !healthKitAuthorized {
                        Button("Conceder permisos de Salud") {
                            requestHealthKitPermissions()
                        }
                        .font(.footnote)
                        .foregroundColor(.blue)
                        .padding(.top, 2)
                    } else {
                        Text("Sin datos de actividad para el periodo seleccionado.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                }
                
                // NUEVA SECCIÓN: Análisis de macros
                GroupBox(label: Label("Análisis de macros", systemImage: "chart.bar.doc.horizontal")) {
                    VStack(alignment: .leading, spacing: 10) {
                        // Objetivos y reales
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Objetivo").font(.caption).foregroundStyle(.secondary)
                                Text("🔥 \(Int(round(calTarget))) kcal")
                                    .font(.headline)
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Consumido").font(.caption).foregroundStyle(.secondary)
                                Text("🔥 \(Int(round(kcalReal))) kcal")
                                    .font(.headline)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            macroPill(name: "P", color: .blue, real: proteinReal, target: proteinTarget, unit: "g")
                            macroPill(name: "C", color: .green, real: carbsReal, target: carbsTarget, unit: "g")
                            macroPill(name: "G", color: .orange, real: fatReal, target: fatTarget, unit: "g")
                        }
                        
                        // Diagnóstico textual
                        VStack(alignment: .leading, spacing: 6) {
                            Text(diagnosisMacro(name: "Proteína", real: proteinReal, target: proteinTarget))
                            Text(diagnosisMacro(name: "Carbohidratos", real: carbsReal, target: carbsTarget))
                            Text(diagnosisMacro(name: "Grasas", real: fatReal, target: fatTarget))
                            Text(diagnosisGlobal(kcalReal: kcalReal, kcalTarget: calTarget))
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        
                        #if canImport(Charts)
                        // Gráfico comparando Objetivo vs Real por macro
                        let macroChartData: [(String, String, Double)] = [
                            ("Proteína", "Objetivo", proteinTarget),
                            ("Proteína", "Real", proteinReal),
                            ("Carbohidratos", "Objetivo", carbsTarget),
                            ("Carbohidratos", "Real", carbsReal),
                            ("Grasas", "Objetivo", fatTarget),
                            ("Grasas", "Real", fatReal)
                        ]
                        Chart(macroChartData, id: \.0) { item in
                            BarMark(
                                x: .value("Macro", item.0),
                                y: .value("g", item.2)
                            )
                            .foregroundStyle(by: .value("Tipo", item.1))
                            .position(by: .value("Tipo", item.1))
                            .annotation(position: .top) {
                                Text("\(Int(round(item.2)))")
                                    .font(.caption2)
                            }
                        }
                        .chartYAxisLabel("g", position: .trailing, alignment: .center)
                        .frame(height: 180)
                        #endif
                        
                        // Nota de cómo se calculan los objetivos
                        Text("Objetivos estimados con Mifflin-St Jeor y tu nivel de actividad y objetivo del perfil.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                if cargandoResumenEntrenoHoy {
                    GroupBox(label: Label("Resumen de tu último entrenamiento (AI)", systemImage: "sparkles")) {
                        ProgressView()
                            .padding(.vertical, 8)
                    }
                } else if let resumen = resumenEntrenoHoy {
                    GroupBox(label: Label("Resumen de tu último entrenamiento (AI)", systemImage: "sparkles")) {
                        Text(resumen)
                            .font(.callout)
                            .padding(.vertical, 8)
                    }
                }

                if cargandoResumenSemana {
                    GroupBox(label: Label("Resumen de tu semana (AI)", systemImage: "calendar")) {
                        ProgressView()
                            .padding(.vertical, 8)
                    }
                } else if let resumen = resumenSemana {
                    GroupBox(label: Label("Resumen de tu semana (AI)", systemImage: "calendar")) {
                        Text(resumen)
                            .font(.callout)
                            .padding(.vertical, 8)
                    }
                }

                HStack(spacing: 16) {
                    resumenBox(title: "Entrenos", value: "\(entrenamientosTerminados.count)", color: .blue)
                    resumenBox(title: "Total", value: formatDuration(seconds: totalDuracion), color: .green)
                    resumenBox(title: "Media", value: formatDuration(seconds: mediaDuracion), color: .orange)
                }
                .padding(.top, 8)

                #if canImport(Charts)
                if entrenamientosTerminados.count > 1 {
                    ChartSection(entrenamientos: entrenamientosTerminados)
                }
                #endif

                GroupBox(label: Label("Progreso por ejercicio", systemImage: "figure.strengthtraining.traditional")) {
                    if slugsEjerciciosRealizados.isEmpty {
                        Text("Añade un ejercicio en un entrenamiento para ver tus gráficos y marcas aquí.")
                            .font(.callout)
                            .padding(.vertical, 12)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Ejercicio seleccionado", selection: Binding(
                                get: { selectedSlug ?? slugsEjerciciosRealizados.first! },
                                set: { selectedSlug = $0 })
                            ) {
                                ForEach(slugsEjerciciosRealizados, id: \.self) { slug in
                                    Text(nombreEjercicioDesdeSlug(slug)).tag(slug as String?)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()

                            if let slug = selectedSlug ?? slugsEjerciciosRealizados.first {
                                resumenEjercicioSeleccionado(slug: slug)
                                #if canImport(Charts)
                                PesoChartView(slug: slug, entrenamientos: entrenamientosTerminados)
                                #endif
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if entrenamientosTerminados.isEmpty {
                    ContentUnavailableView(
                        "Aún no tienes entrenos finalizados",
                        systemImage: "chart.bar.doc.horizontal",
                        description: Text("Termina tu primer entreno para ver tu progreso aquí.")
                    )
                    .padding(.vertical)
                }
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal)
            .padding(.vertical, 22)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Progreso")
        .onAppear {
            requestHealthKitPermissions()
            if selectedSlug == nil, let primero = ejercicioMasFrecuenteSlug ?? slugsEjerciciosRealizados.first {
                selectedSlug = primero
            }
            if let storedID = UserDefaults.standard.string(forKey: resumenEntrenoIDKey),
               let uuid = UUID(uuidString: storedID) {
                lastResumenEntrenoID = uuid
            }
            resumenEntrenoHoy = UserDefaults.standard.string(forKey: resumenEntrenoKey)
            generarResumenEntrenoHoy()

            // NO llamar directamente a generarResumenSemana()
            checkAndGenerateResumenSemana()
            
            updateCaloriasHKYConsumidas()
        }
        .onChange(of: periodoSeleccionado) {
            updateCaloriasHKYConsumidas()
        }
    }
    
    private func requestHealthKitPermissions() {
        guard !healthKitAuthorized else {
            updateCaloriasHKYConsumidas()
            return
        }
        
        requestingPermissions = true
        
        HealthKitManager.shared.requestAuthorization { [self] success, error in
            DispatchQueue.main.async {
                self.requestingPermissions = false
                self.healthKitAuthorized = success
                
                if success {
                    // Actualizar datos después de obtener permisos
                    self.updateCaloriasHKYConsumidas()
                } else {
                    print("Error al obtener permisos HealthKit: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
    
    private func updateCaloriasHKYConsumidas() {
        burnedCaloriesHK = 0
        consumedCalories = 0
        
        // NUEVO: reset de macros reales
        proteinReal = 0
        carbsReal = 0
        fatReal = 0
        kcalReal = 0
        
        // Calcular rango de fechas del periodo
        let calendar = Calendar.current
        let now = Date()
        var startDate: Date
        let endDate = now
        
        switch periodoSeleccionado {
        case .hoy:
            startDate = calendar.startOfDay(for: now)
        case .semana:
            startDate = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        case .mes:
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? calendar.startOfDay(for: now)
        }
        
        // Calcular calorías y macros consumidas en el periodo
        let mealsPeriodo = meals.filter { meal in
            let fecha = meal.date
            return fecha >= startDate && fecha <= endDate
        }
        consumedCalories = mealsPeriodo.reduce(0) { $0 + $1.totalKcal }
        kcalReal = consumedCalories
        proteinReal = mealsPeriodo.reduce(0) { $0 + $1.totalProtein }
        carbsReal   = mealsPeriodo.reduce(0) { $0 + $1.totalCarbs }
        fatReal     = mealsPeriodo.reduce(0) { $0 + $1.totalFat }
        
        // Recalcular objetivos a partir del perfil
        recalculateTargets()
        
        // Solo obtener datos de HealthKit si tenemos permisos
        guard healthKitAuthorized else {
            burnedCaloriesHK = 0
            return
        }
        
        HealthKitManager.shared.fetchTotalEnergyBurned(startDate: startDate, endDate: endDate) { calories in
            DispatchQueue.main.async {
                self.burnedCaloriesHK = calories
            }
        }
    }
    
    // NUEVO: recalcular objetivos en base al Perfil
    private func recalculateTargets() {
        guard let perfil = perfiles.first else {
            // Sin perfil: deja targets en 0
            calTarget = 0
            proteinTarget = 0
            fatTarget = 0
            carbsTarget = 0
            return
        }
        let cal = calorieTarget(for: perfil)
        let macros = macroTargets(for: perfil, calTarget: cal)
        calTarget = cal
        proteinTarget = macros.p
        fatTarget = macros.f
        carbsTarget = macros.c
    }

    private var burnedCalories: Double {
        // Estimación sencilla: duración total en minutos * 8 kcal/min
        let minutos = totalDuracion / 60
        return minutos * 8
    }

    private func checkAndGenerateResumenSemana() {
        cargandoResumenSemana = true

        // Detectar si hay un entreno terminado hoy
        let today = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: today)

        // Ver entrenos con endDate == hoy (comparar solo fecha)
        let entrenosTerminadosHoy = entrenamientosTerminados.filter {
            guard let end = $0.endDate else { return false }
            return dateFormatter.string(from: end) == todayString
        }

        if entrenosTerminadosHoy.isEmpty {
            // No hay entreno terminado hoy, mostrar mensaje y no generar resumen
            resumenSemana = "El resumen semanal se generará al terminar un entrenamiento hoy."
            cargandoResumenSemana = false
            return
        }

        // Hay entreno terminado hoy, comprobar si resumen para hoy ya existe
        if let storedDateString = UserDefaults.standard.string(forKey: resumenSemanaDateKey),
           storedDateString == todayString,
           let storedResumen = UserDefaults.standard.string(forKey: resumenSemanaKey) {
            // Ya existe resumen para hoy, cargarlo
            resumenSemana = storedResumen
            cargandoResumenSemana = false
        } else {
            // No existe resumen para hoy, generarlo y guardar
            generarResumenSemana()
        }
    }

    private var entrenamientosTerminados: [Entrenamiento] {
        entrenamientos.filter { $0.endDate != nil && $0.startDate != nil }
    }

    private var totalDuracion: TimeInterval {
        entrenamientosTerminados.reduce(0) { sum, e in
            guard let start = e.startDate, let end = e.endDate else { return sum }
            return sum + end.timeIntervalSince(start)
        }
    }
    
    private var mediaDuracion: TimeInterval {
        guard !entrenamientosTerminados.isEmpty else { return 0 }
        return totalDuracion / Double(entrenamientosTerminados.count)
    }

    private var slugsEjerciciosRealizados: [String] {
        let ejercicios = entrenamientosTerminados.flatMap { $0.ejercicios }
        let slugs = ejercicios.map { $0.slug }
        return Array(Set(slugs)).sorted()
    }
    
    private func resumenEjercicioSeleccionado(slug: String) -> some View {
        let ejercicios = entrenamientosTerminados.flatMap { $0.ejercicios }.filter { $0.slug == slug }
        let series = ejercicios.flatMap { $0.sets }
        return Group {
            if series.isEmpty {
                Text("Aún no has registrado este ejercicio.")
                    .font(.callout).foregroundStyle(.secondary).padding(.top, 8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mejores marcas: \(nombreEjercicioDesdeSlug(slug))").font(.headline)
                    let maxPeso = series.max(by: { $0.weight < $1.weight })?.weight ?? 0
                    let maxReps = series.max(by: { $0.reps < $1.reps })?.reps ?? 0
                    HStack {
                        Text("Peso: \(String(format: "%.1f", maxPeso)) kg").font(.body)
                        Spacer()
                        Text("Reps: \(maxReps)").font(.body)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private var ejercicioMasFrecuenteSlug: String? {
        let ejercicios = entrenamientosTerminados.flatMap { $0.ejercicios }
        let counts = Dictionary(grouping: ejercicios, by: { $0.slug }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private var resumenVisual: some View {
        HStack(spacing: 16) {
            resumenBox(title: "Entrenos", value: "\(entrenamientosTerminados.count)", color: .blue)
            resumenBox(title: "Total", value: formatDuration(seconds: totalDuracion), color: .green)
            resumenBox(title: "Media", value: formatDuration(seconds: mediaDuracion), color: .orange)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func resumenBox(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
    }
    
    // NUEVO: píldora de macro con color e indicador de desviación
    private func macroPill(name: String, color: Color, real: Double, target: Double, unit: String) -> some View {
        let pct = target > 0 ? (real / target) : 0
        let statusColor: Color = pct < 0.9 ? .orange : (pct > 1.1 ? .red : .green)
        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(name).font(.caption).foregroundStyle(.secondary)
            Text("\(Int(round(real)))\(unit)").font(.subheadline).bold()
            Text("/ \(Int(round(target)))\(unit)").font(.caption2).foregroundStyle(.secondary)
            Circle().fill(statusColor).frame(width: 8, height: 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
    }

    private func duracionText(from start: Date, to end: Date) -> String {
        let interval = Int(end.timeIntervalSince(start))
        let h = interval / 3600
        let m = (interval % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        } else {
            return "\(m)m"
        }
    }
    
    private func formatDuration(seconds: TimeInterval) -> String {
        let s = Int(seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        } else {
            return "\(m)m"
        }
    }

    private func generarResumenEntrenoHoy() {
        cargandoResumenEntrenoHoy = true
        guard let entreno = entrenamientosTerminados.first else {
            cargandoResumenEntrenoHoy = false
            return
        }
        let currentID = entreno.id
        if currentID == lastResumenEntrenoID, resumenEntrenoHoy != nil {
            cargandoResumenEntrenoHoy = false
            return
        }
        resumenEntrenoHoy = nil
        
        let perfil = perfiles.first
        var perfilStr = ""
        if let perfil = perfil {
            var restriccionesStr = ""
            if let restricciones = perfil.restricciones, !restricciones.isEmpty {
                restriccionesStr = ", Restricciones: \(restricciones)"
            }
            perfilStr = "Perfil: Edad \(perfil.edad), Peso \(Int(perfil.peso)) kg, Altura \(Int(perfil.altura)) cm, Sexo \(perfil.sexo), Objetivo: \(perfil.objetivo), Nivel actividad: \(perfil.nivelActividad)\(restriccionesStr)\n"
        }
        
        let grupos = entreno.gruposMusculares.map { $0.localizedName }.joined(separator: ", ")
        let ejerciciosStr = entreno.ejercicios.map { ejercicio -> String in
            let exerciseSeed = defaultExercises.first(where: { $0.slug == ejercicio.slug })
            let setsText = ejercicio.sets.map { set -> String in
                if let seed = exerciseSeed {
                    switch seed.type {
                    case .duration:
                        return "\(Int(set.reps))seg@\(String(format: "%.1f", set.weight))kg"
                    case .reps:
                        return "\(set.reps)x\(String(format: "%.1f", set.weight))kg"
                    }
                } else {
                    // Por defecto reps
                    return "\(set.reps)x\(String(format: "%.1f", set.weight))kg"
                }
            }.joined(separator: ", ")
            return "\(nombreEjercicioDesdeSlug(ejercicio.slug)): \(setsText)"
        }.joined(separator: "\n")
        let gruposTrabajados = Set(entreno.gruposMusculares)
        let ejerciciosDisponibles = defaultExercises.filter { gruposTrabajados.contains($0.group) }
            .map { $0.name }
            .joined(separator: ", ")
        
        let prompt = """
            \(perfilStr)Eres un entrenador personal experto en hipertrofia. Analiza este entrenamiento que he registrado hoy:
            - Grupos musculares trabajados: \(grupos)
            - Ejercicios realizados:
            \(ejerciciosStr)

            Quiero que me digas:
            1. Si los ejercicios que hice cubren bien todos los músculos trabajados.
            2. Si tendría que haber añadido algún otro ejercicio de esta lista para que el entrenamiento fuera más completo: \(ejerciciosDisponibles). Explica por qué lo sugieres.
            3. Si las series, repeticiones y pesos que usé están bien para un objetivo de hipertrofia o si debería hacer algún ajuste.

            Responde en español, de forma clara, directa y en un máximo de dos párrafos.
            """
        print(prompt)
        Task {
            let session = LanguageModelSession(instructions: "Eres un entrenador personal crítico, experto en mejora física y fuerza. Da consejos realistas, analiza posibles errores y propone cambios concretos. Responde en español.")
            if let respuesta = try? await session.respond(to: prompt) {
                await MainActor.run {
                    resumenEntrenoHoy = respuesta.content
                    lastResumenEntrenoID = currentID
                    UserDefaults.standard.setValue(currentID.uuidString, forKey: resumenEntrenoIDKey)
                    UserDefaults.standard.setValue(respuesta.content, forKey: resumenEntrenoKey)
                }
            }
            await MainActor.run { cargandoResumenEntrenoHoy = false }
        }
    }
    
    private func generarResumenSemana() {
        cargandoResumenSemana = true
        
        // Calcular fecha lunes semana actual (comienzo semana)
        let today = Date()
        guard let monday = Calendar.current.dateInterval(of: .weekOfYear, for: today)?.start else {
            resumenSemana = "No se pudo calcular el inicio de la semana."
            cargandoResumenSemana = false
            return
        }
        
        // Filtrar entrenamientos de la semana (startDate entre lunes y hoy)
        let entrenosSemana = entrenamientosTerminados.filter {
            guard let start = $0.startDate else { return false }
            return start >= monday && start <= today
        }
        
        if entrenosSemana.isEmpty {
            resumenSemana = "No has realizado entrenamientos esta semana."
            cargandoResumenSemana = false
            return
        }
        
        let perfil = perfiles.first
        var perfilStr = ""
        if let perfil = perfil {
            var restriccionesStr = ""
            if let restricciones = perfil.restricciones, !restricciones.isEmpty {
                restriccionesStr = ", Restricciones: \(restricciones)"
            }
            perfilStr = "Perfil: Edad \(perfil.edad), Peso \(Int(perfil.peso)) kg, Altura \(Int(perfil.altura)) cm, Sexo \(perfil.sexo), Objetivo \(perfil.objetivo), Nivel actividad: \(perfil.nivelActividad)\(restriccionesStr)\n"
        }
        
        // Agrupar y listar grupos trabajados en la semana
        let gruposSet = Set(entrenosSemana.flatMap { $0.gruposMusculares })
        let grupos = gruposSet.map { $0.localizedName }.joined(separator: ", ")
        
        // Ejercicios realizados en la semana con sets y reps/pesos resumidos
        let ejerciciosSemana = entrenosSemana.flatMap { $0.ejercicios }
        let ejerciciosPorSlug = Dictionary(grouping: ejerciciosSemana, by: { $0.slug })
        
        // Crear listado de entrenamientos con detalle para IA
        let diaFormatter = DateFormatter()
        diaFormatter.locale = Locale(identifier: "es_ES")
        diaFormatter.dateFormat = "EEEE"
        let fechaFormatter = DateFormatter()
        fechaFormatter.dateFormat = "dd/MM"
        
        let entrenosOrdenados = entrenosSemana.sorted { ($0.startDate ?? Date()) < ($1.startDate ?? Date()) }
        
        let sesionesDetalleStr = entrenosOrdenados.map { entreno -> String in
            let diaSemana = entreno.startDate.map { diaFormatter.string(from: $0).capitalized } ?? "Día desconocido"
            let fechaCorta = entreno.startDate.map { fechaFormatter.string(from: $0) } ?? "??/??"
            let gruposTrabajados = entreno.gruposMusculares.map { $0.localizedName }.joined(separator: ", ")
            let ejerciciosNames = entreno.ejercicios.map { nombreEjercicioDesdeSlug($0.slug) }.joined(separator: ", ")
            return "- \(diaSemana) (\(fechaCorta)): Grupos trabajados: \(gruposTrabajados). Ejercicios: \(ejerciciosNames)"
        }.joined(separator: "\n")
        
        let ejerciciosStr = ejerciciosPorSlug.map { slug, ejercicios -> String in
            let exerciseSeed = defaultExercises.first(where: { $0.slug == slug })
            // sumar total sets, reps y peso medio aproximado
            let allSets = ejercicios.flatMap { $0.sets }
            let totalSets = allSets.count
            let totalReps = allSets.reduce(0) { $0 + $1.reps }
            let avgWeight = allSets.isEmpty ? 0 : allSets.reduce(0.0) { $0 + Double($1.weight) } / Double(allSets.count)
            
            var setsText = ""
            if let seed = exerciseSeed {
                switch seed.type {
                case .duration:
                    setsText = "\(totalReps) seg, peso medio: \(String(format: "%.1f", avgWeight)) kg"
                case .reps:
                    setsText = "\(totalSets) sets, \(totalReps) reps, peso medio: \(String(format: "%.1f", avgWeight)) kg"
                }
            } else {
                setsText = "\(totalSets) sets, \(totalReps) reps, peso medio: \(String(format: "%.1f", avgWeight)) kg"
            }
            return "\(nombreEjercicioDesdeSlug(slug)): \(setsText)"
        }.sorted().joined(separator: "\n")
        
        let totalSesiones = entrenosSemana.count
        
        let prompt = """
\(perfilStr)Eres un entrenador personal experto en hipertrofia. Analiza este resumen semanal de entrenamientos (desde el lunes hasta hoy):

Entrenamientos de la semana:
\(sesionesDetalleStr)

- Total de sesiones: \(totalSesiones)
- Grupos musculares trabajados: \(grupos)
- Ejercicios realizados y resumen de sets/reps/peso:
\(ejerciciosStr)

Valora el equilibrio del entrenamiento semanal, indica si falta algún grupo muscular importante o si hay sobrecarga en otros. Proporciona consejos para mejorar el resto de la semana, incluyendo ejercicios recomendados o ajustes en repeticiones/pesos. Sé claro, directo y concreto en español. Limita tu respuesta a dos párrafos.
"""
        print(prompt)
        
        Task {
            let session = LanguageModelSession(instructions: "Eres un entrenador personal crítico, experto en mejora física y fuerza. Da consejos realistas, analiza posibles errores y propone cambios concretos. Responde en español.")
            if let respuesta = try? await session.respond(to: prompt) {
                await MainActor.run {
                    resumenSemana = respuesta.content
                    // Guardar resumen y fecha en UserDefaults
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    let todayString = dateFormatter.string(from: Date())
                    UserDefaults.standard.setValue(respuesta.content, forKey: resumenSemanaKey)
                    UserDefaults.standard.setValue(todayString, forKey: resumenSemanaDateKey)
                }
            } else {
                await MainActor.run {
                    resumenSemana = "No se pudo generar el resumen semanal."
                }
            }
            await MainActor.run {
                cargandoResumenSemana = false
            }
        }
    }
    
    // MARK: - Helpers de objetivos y diagnóstico (NUEVOS)
    
    private func bmr(for perfil: Perfil) -> Double {
        let peso = perfil.peso
        let altura = perfil.altura
        let edad = Double(perfil.edad)
        let sexoLower = perfil.sexo.lowercased()
        // Mifflin-St Jeor
        let base = 10 * peso + 6.25 * altura - 5 * edad
        if sexoLower.contains("fem") {
            return base - 161
        } else {
            return base + 5
        }
    }
    
    private func activityFactor(from nivel: String) -> Double {
        let lower = nivel.lowercased()
        if lower.contains("alta") { return 1.725 }
        if lower.contains("moder") { return 1.55 }
        if lower.contains("baja") { return 1.2 }
        // fallback razonable
        return 1.4
    }
    
    private func calorieTarget(for perfil: Perfil) -> Double {
        let b = bmr(for: perfil)
        let af = activityFactor(from: perfil.nivelActividad)
        let objetivoLower = perfil.objetivo.lowercased()
        let ajuste: Double
        if objetivoLower.contains("ganar") {
            ajuste = 0.12 // +12%
        } else if objetivoLower.contains("perder") {
            ajuste = -0.15 // -15%
        } else {
            ajuste = 0.0
        }
        return (b * af) * (1.0 + ajuste)
    }
    
    private func macroTargets(for perfil: Perfil, calTarget: Double) -> (p: Double, c: Double, f: Double) {
        let peso = perfil.peso
        let objetivoLower = perfil.objetivo.lowercased()
        // Proteína g/kg
        let pPerKg: Double
        if objetivoLower.contains("ganar") {
            pPerKg = 2.0
        } else if objetivoLower.contains("perder") {
            pPerKg = 2.2
        } else {
            pPerKg = 1.8
        }
        // Grasas g/kg
        let fPerKg: Double = objetivoLower.contains("perder") ? 0.7 : 0.8
        
        let pGr = max(0, pPerKg * peso)
        let fGr = max(0, fPerKg * peso)
        
        let kcalFromP = pGr * 4
        let kcalFromF = fGr * 9
        let remaining = max(0, calTarget - kcalFromP - kcalFromF)
        let cGr = remaining / 4.0
        
        return (p: pGr, c: cGr, f: fGr)
    }
    
    private func diagnosisMacro(name: String, real: Double, target: Double) -> String {
        guard target > 0 else { return "\(name): sin objetivo definido." }
        let ratio = real / target
        let diff = real - target
        let absDiff = abs(diff)
        let sign = diff >= 0 ? "+" : "-"
        
        if ratio < 0.9 {
            return "\(name): te faltan \(Int(round(absDiff))) g (−\(Int(round((1 - ratio) * 100)))%)."
        } else if ratio > 1.1 {
            return "\(name): te pasas \(Int(round(absDiff))) g (\(sign)\(Int(round((ratio - 1) * 100)))%)."
        } else {
            return "\(name): OK (±10%)."
        }
    }
    
    private func diagnosisGlobal(kcalReal: Double, kcalTarget: Double) -> String {
        guard kcalTarget > 0 else { return "Calorías: sin objetivo definido." }
        let ratio = kcalReal / kcalTarget
        let diff = Int(round(kcalReal - kcalTarget))
        if ratio < 0.95 {
            return "Calorías: déficit no planificado (\(diff) kcal)."
        } else if ratio > 1.05 {
            return "Calorías: superávit no planificado (+\(diff) kcal)."
        } else {
            return "Calorías: dentro de objetivo (±5%)."
        }
    }
}

private func nombreEjercicioDesdeSlug(_ slug: String) -> String {
    if let seed = defaultExercises.first(where: { $0.slug == slug }) {
        return seed.name
    }
    return slug
}

#if canImport(Charts)
private struct ChartSection: View {
    let entrenamientos: [Entrenamiento]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Duración últimos entrenos")
                .font(.headline)
            
            Chart(entrenamientos.prefix(14), id: \Entrenamiento.id) { e in
                if let start = e.startDate, let end = e.endDate {
                    BarMark(
                        x: .value("Fecha", start, unit: .day),
                        y: .value("Duración", end.timeIntervalSince(start) / 60)
                    )
                    .foregroundStyle(Color.accentColor)
                }
            }
            .chartYAxisLabel("minutos", position: .trailing, alignment: .center)
            .frame(height: 180)
        }
    }
}
#endif

#if canImport(Charts)
private struct PesoChartView: View {
    let slug: String
    let entrenamientos: [Entrenamiento]
    
    var body: some View {
        let sets = entrenamientos
            .flatMap { $0.ejercicios }
            .filter { $0.slug == slug }
            .flatMap { $0.sets }
            .sorted(by: { $0.createdAt < $1.createdAt })
        
        let exerciseSeed = defaultExercises.first(where: { $0.slug == slug })
        
        VStack(alignment: .leading, spacing: 12) {
            if let seed = exerciseSeed, seed.type == .duration {
                Text("Evolución duración: \(nombreEjercicioDesdeSlug(slug))")
                    .font(.headline)
                if sets.isEmpty {
                    Text("No hay datos para este ejercicio.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Chart(sets, id: \.createdAt) { set in
                        PointMark(
                            x: .value("Fecha", set.createdAt),
                            y: .value("Duración", set.duration)
                        )
                        .foregroundStyle(Color.accentColor)
                    }
                    .chartYAxisLabel("segundos", position: .trailing, alignment: .center)
                    .frame(height: 180)
                }
            } else {
                Text("Evolución peso: \(nombreEjercicioDesdeSlug(slug))")
                    .font(.headline)
                if sets.isEmpty {
                    Text("No hay datos para este ejercicio.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Chart(sets, id: \.createdAt) { set in
                        PointMark(
                            x: .value("Fecha", set.createdAt),
                            y: .value("Peso", set.weight)
                        )
                        .foregroundStyle(Color.accentColor)
                    }
                    .chartYAxisLabel("kg", position: .trailing, alignment: .center)
                    .frame(height: 180)
                }
            }
        }
        .padding(.top, 16)
    }
}
#endif

#Preview {
    ProgresoView()
}
