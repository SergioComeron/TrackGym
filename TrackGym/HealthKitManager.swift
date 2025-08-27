import Foundation
import HealthKit

/// Wraps HealthKit access for logging nutrition (protein, carbs, fat, kcal).
/// Ensure the target has the HealthKit capability enabled and Info.plist contains
/// `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` strings.

class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()

    // Retain observer queries for nutrition types
    private var nutritionObserverQueries: [HKObserverQuery] = []

    private init() {}

    // Types for nutrition
    private let proteinType = HKObjectType.quantityType(forIdentifier: .dietaryProtein)!
    private let carbsType = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!
    private let fatType = HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)!
    private let energyType = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!

    // Convenience array for all nutrition types
    private var nutritionTypes: [HKQuantityType] {
        [proteinType, carbsType, fatType, energyType]
    }

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Health data not available on this device"]))
            return
        }

        let shareTypes: Set<HKSampleType> = [proteinType, carbsType, fatType, energyType]
        let readTypes: Set<HKObjectType> = [proteinType, carbsType, fatType, energyType]

        healthStore.requestAuthorization(toShare: shareTypes, read: readTypes, completion: completion)
    }

    func authorizationStatuses() -> [HKSampleType: HKAuthorizationStatus] {
        let types: [HKSampleType] = [proteinType, carbsType, fatType, energyType]
        var result: [HKSampleType: HKAuthorizationStatus] = [:]
        for t in types {
            result[t] = healthStore.authorizationStatus(for: t)
        }
        return result
    }

    /// Enables Background Delivery for all nutrition types.
    /// Requires the app capability: Background Modes → HealthKit.
    func enableBackgroundDeliveryForNutrition(frequency: HKUpdateFrequency = .immediate, completion: ((Bool, Error?) -> Void)? = nil) {
        let group = DispatchGroup()
        var overallSuccess = true
        var lastError: Error?

        for type in nutritionTypes {
            group.enter()
            healthStore.enableBackgroundDelivery(for: type, frequency: frequency) { success, error in
                overallSuccess = overallSuccess && success
                if let error { lastError = error }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion?(overallSuccess, lastError)
        }
    }

    /// Disables Background Delivery for all nutrition types.
    func disableBackgroundDeliveryForNutrition(completion: ((Bool, Error?) -> Void)? = nil) {
        let group = DispatchGroup()
        var overallSuccess = true
        var lastError: Error?

        for type in nutritionTypes {
            group.enter()
            healthStore.disableBackgroundDelivery(for: type) { success, error in
                overallSuccess = overallSuccess && success
                if let error { lastError = error }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion?(overallSuccess, lastError)
        }
    }

    /// Starts HKObserverQuery for each nutrition type. When iOS delivers new data in background,
    /// the closure is called with the identifier so you can refresh UI or run anchored queries.
    func startNutritionObservers(onUpdate: @escaping (_ identifier: HKQuantityTypeIdentifier) -> Void) {
        stopNutritionObservers()
        for type in nutritionTypes {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completionHandler, error in
                if error == nil {
                    onUpdate(HKQuantityTypeIdentifier(rawValue: type.identifier))
                }
                completionHandler()
            }
            nutritionObserverQueries.append(query)
            healthStore.execute(query)
        }
    }

    /// Stops all nutrition observer queries.
    func stopNutritionObservers() {
        for q in nutritionObserverQueries { healthStore.stop(q) }
        nutritionObserverQueries.removeAll()
    }

    // MARK: - Individual Food Entry Methods
    
    /// ✅ NEW: Saves a single food item as an individual entry in HealthKit
    /// This is optimized for real-time logging of individual foods as they're added
    func saveFoodEntry(
        date: Date,
        foodName: String,
        grams: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        kcal: Double,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        print("🍎 [HealthKit] Saving individual food: \(foodName) (\(grams)g)")
        print("📊 [HealthKit] Macros: P:\(protein)g C:\(carbs)g F:\(fat)g K:\(kcal)kcal")
        
        let proteinUnit = HKUnit.gram()
        let carbsUnit = HKUnit.gram()
        let fatUnit = HKUnit.gram()
        let energyUnit = HKUnit.kilocalorie()

        // Enhanced metadata for better tracking
        let metadata: [String: Any] = [
            HKMetadataKeyFoodType: foodName,
            "TrackGym_FoodName": foodName,
            "TrackGym_Grams": grams,
            "TrackGym_EntryType": "IndividualFood"
        ]

        // Create samples with zero values filtered out (HealthKit doesn't like 0.0 samples)
        var samples: [HKQuantitySample] = []
        
        if protein > 0 {
            samples.append(HKQuantitySample(
                type: proteinType,
                quantity: HKQuantity(unit: proteinUnit, doubleValue: protein),
                start: date,
                end: date,
                metadata: metadata
            ))
        }
        
        if carbs > 0 {
            samples.append(HKQuantitySample(
                type: carbsType,
                quantity: HKQuantity(unit: carbsUnit, doubleValue: carbs),
                start: date,
                end: date,
                metadata: metadata
            ))
        }
        
        if fat > 0 {
            samples.append(HKQuantitySample(
                type: fatType,
                quantity: HKQuantity(unit: fatUnit, doubleValue: fat),
                start: date,
                end: date,
                metadata: metadata
            ))
        }
        
        if kcal > 0 {
            samples.append(HKQuantitySample(
                type: energyType,
                quantity: HKQuantity(unit: energyUnit, doubleValue: kcal),
                start: date,
                end: date,
                metadata: metadata
            ))
        }

        guard !samples.isEmpty else {
            print("⚠️ [HealthKit] No non-zero values to save for \(foodName)")
            completion(false, NSError(domain: "HealthKit", code: 2, userInfo: [NSLocalizedDescriptionKey: "No non-zero nutritional values to save"]))
            return
        }

        // Try to create a food correlation first (shows as single item in Health app)
        if let foodType = HKCorrelationType.correlationType(forIdentifier: .food) {
            let correlation = HKCorrelation(
                type: foodType,
                start: date,
                end: date,
                objects: Set(samples),
                metadata: metadata
            )
            
            healthStore.save(correlation) { [weak self] success, error in
                if success {
                    print("✅ [HealthKit] Successfully saved food correlation: \(foodName)")
                    completion(true, nil)
                } else {
                    print("⚠️ [HealthKit] Correlation failed, falling back to individual samples")
                    // Fallback to individual samples
                    self?.healthStore.save(samples) { fallbackSuccess, fallbackError in
                        if fallbackSuccess {
                            print("✅ [HealthKit] Successfully saved individual samples: \(foodName)")
                        } else {
                            print("❌ [HealthKit] Failed to save samples: \(fallbackError?.localizedDescription ?? "Unknown error")")
                        }
                        completion(fallbackSuccess, fallbackError)
                    }
                }
            }
        } else {
            // Very old iOS versions without correlation support
            healthStore.save(samples) { success, error in
                if success {
                    print("✅ [HealthKit] Successfully saved individual samples (legacy): \(foodName)")
                } else {
                    print("❌ [HealthKit] Failed to save samples (legacy): \(error?.localizedDescription ?? "Unknown error")")
                }
                completion(success, error)
            }
        }
    }

    // MARK: - Legacy Methods (kept for compatibility)
    
    func saveMealMacros(date: Date, protein: Double, carbs: Double, fat: Double, kcal: Double, completion: ((Bool, Error?) -> Void)? = nil) {
        let proteinUnit = HKUnit.gram()
        let carbsUnit = HKUnit.gram()
        let fatUnit = HKUnit.gram()
        let energyUnit = HKUnit.kilocalorie()
        let metadata = [HKMetadataKeyFoodType: "TrackGym Meal"]

        let samples: [HKQuantitySample] = [
            HKQuantitySample(type: proteinType, quantity: HKQuantity(unit: proteinUnit, doubleValue: protein), start: date, end: date, metadata: metadata),
            HKQuantitySample(type: carbsType, quantity: HKQuantity(unit: carbsUnit, doubleValue: carbs), start: date, end: date, metadata: metadata),
            HKQuantitySample(type: fatType, quantity: HKQuantity(unit: fatUnit, doubleValue: fat), start: date, end: date, metadata: metadata),
            HKQuantitySample(type: energyType, quantity: HKQuantity(unit: energyUnit, doubleValue: kcal), start: date, end: date, metadata: metadata)
        ]
        healthStore.save(samples) { success, error in
            completion?(success, error)
        }
    }

    /// Saves a grouped Food correlation so the nutrients appear as a single meal in the Health app.
    /// If correlation creation fails (older iOS), this falls back to saving plain samples.
    ///
    /// - Parameters:
    ///   - date: The date of the meal.
    ///   - name: The name of the meal.
    ///   - protein: Protein amount in grams.
    ///   - carbs: Carbohydrates amount in grams.
    ///   - fat: Fat amount in grams.
    ///   - kcal: Energy amount in kilocalories.
    ///   - completion: Optional completion handler called with success flag, UUID of saved correlation or first sample (if applicable), and error.
    func saveMealAsFoodCorrelation(date: Date, name: String, protein: Double, carbs: Double, fat: Double, kcal: Double, completion: ((Bool, UUID?, Error?) -> Void)? = nil) {
        let proteinUnit = HKUnit.gram()
        let carbsUnit = HKUnit.gram()
        let fatUnit = HKUnit.gram()
        let energyUnit = HKUnit.kilocalorie()

        let metadata: [String: Any] = [
            HKMetadataKeyFoodType: name,
        ]

        let nutrientSamples: Set<HKSample> = [
            HKQuantitySample(type: proteinType, quantity: HKQuantity(unit: proteinUnit, doubleValue: protein), start: date, end: date),
            HKQuantitySample(type: carbsType, quantity: HKQuantity(unit: carbsUnit, doubleValue: carbs), start: date, end: date),
            HKQuantitySample(type: fatType, quantity: HKQuantity(unit: fatUnit, doubleValue: fat), start: date, end: date),
            HKQuantitySample(type: energyType, quantity: HKQuantity(unit: energyUnit, doubleValue: kcal), start: date, end: date)
        ]

        if let foodType = HKCorrelationType.correlationType(forIdentifier: .food) {
            let correlation = HKCorrelation(type: foodType, start: date, end: date, objects: nutrientSamples, metadata: metadata)
            healthStore.save(correlation) { success, error in
                if success {
                    completion?(true, correlation.uuid, nil)
                } else {
                    // Fallback to saving raw samples if correlation fails
                    self.healthStore.save(Array(nutrientSamples)) { s, e in
                        completion?(s, (s ? Array(nutrientSamples).first?.uuid : nil), e)
                    }
                }
            }
        } else {
            // Very old systems without Food correlation support
            healthStore.save(Array(nutrientSamples)) { success, error in
                completion?(success, (success ? Array(nutrientSamples).first?.uuid : nil), error)
            }
        }
    }
    
    /// Deletes a HealthKit object (sample or correlation) by its UUID.
    /// - Parameters:
    ///   - type: The HKSampleType (e.g. correlation or quantity type)
    ///   - uuid: The UUID of the object to delete
    ///   - completion: Completion handler with success flag and error
    func deleteSampleByUUID(type: HKSampleType, uuid: UUID, completion: @escaping (Bool, Error?) -> Void) {
        print("[HK] Intentando borrar objeto de tipo: \(type), UUID: \(uuid)")
        let predicate = HKQuery.predicateForObject(with: uuid)
        print("[HK] Predicado: \(predicate)")
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: nil) { [weak self] _, samples, error in
            print("[HK] Query devuelta: \(samples?.count ?? 0) muestras, error: \(error?.localizedDescription ?? "nil")")
            if let sample = samples?.first {
                print("[HK] Eliminando sample: \(sample)")
                self?.healthStore.delete(sample) { success, err in
                    print("[HK] Resultado del borrado: success=\(success), error=\(err?.localizedDescription ?? "nil")")
                    completion(success, err)
                }
            } else {
                print("[HK] No se encontró muestra para el UUID proporcionado (normal para componentes de correlación)")
                completion(true, nil) // Cambiar a true porque es el comportamiento esperado
            }
        }
        healthStore.execute(query)
    }

//    func deleteAllSamplesByUUID(uuid: UUID, completion: @escaping (Bool, Error?) -> Void) {
//        // Solo necesitas borrar la correlación
//        if let foodCorrelationType = HKCorrelationType.correlationType(forIdentifier: .food) {
//            deleteSampleByUUID(type: foodCorrelationType, uuid: uuid) { success, error in
//                print("[HK] Borrado de correlación food para UUID \(uuid): success=\(success)")
//                completion(success, error)
//            }
//        } else {
//            completion(false, NSError(domain: "HealthKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Food correlation type not available"]))
//        }
//    }
    func deleteAllSamplesByUUID(uuid: UUID, completion: @escaping (Bool, Error?) -> Void) {
            deleteAllSamplesByUUIDWithVerification(uuid: uuid, completion: completion)
        }
    
    func deleteAllSamplesByUUIDWithVerification(uuid: UUID, completion: @escaping (Bool, Error?) -> Void) {
            print("[HK] 🔍 === INICIO PROCESO BORRADO ===")
            print("[HK] UUID a borrar: \(uuid)")
            
            // PASO 1: Verificar QUÉ existe ANTES del borrado
            verifyBeforeDeletion(uuid: uuid) { [weak self] foundSamples in
                if foundSamples.isEmpty {
                    print("[HK] ❌ No se encontraron muestras para borrar")
                    completion(false, NSError(domain: "HealthKit", code: 404, userInfo: [NSLocalizedDescriptionKey: "No samples found"]))
                    return
                }
                
                print("[HK] 📋 Muestras encontradas ANTES del borrado: \(foundSamples.count)")
                foundSamples.forEach { sample in
                    print("[HK]   └─ \(sample.sampleType.identifier): \(sample.uuid)")
                }
                
                // PASO 2: Intentar el borrado
                self?.performActualDeletion(samples: foundSamples) { success, error in
                    if success {
                        print("[HK] ✅ Borrado reportado como exitoso")
                        
                        // PASO 3: Verificar DESPUÉS del borrado
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self?.verifyAfterDeletion(uuid: uuid) { remainingSamples in
                                let actualSuccess = remainingSamples.isEmpty
                                print("[HK] 🔍 Verificación DESPUÉS: \(remainingSamples.count) muestras restantes")
                                
                                if actualSuccess {
                                    print("[HK] 🎉 BORRADO CONFIRMADO - No quedan muestras")
                                } else {
                                    print("[HK] ❌ BORRADO FALLÓ - Quedan \(remainingSamples.count) muestras:")
                                    remainingSamples.forEach { sample in
                                        print("[HK]   └─ \(sample.sampleType.identifier): \(sample.uuid)")
                                    }
                                }
                                
                                completion(actualSuccess, actualSuccess ? nil : NSError(domain: "HealthKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Deletion verification failed"]))
                            }
                        }
                    } else {
                        print("[HK] ❌ Borrado reportado como fallido: \(error?.localizedDescription ?? "?")")
                        completion(false, error)
                    }
                }
            }
        }
        
        private func verifyBeforeDeletion(uuid: UUID, completion: @escaping ([HKSample]) -> Void) {
            let types: [HKSampleType] = [
                HKCorrelationType.correlationType(forIdentifier: .food)!,
                proteinType, carbsType, fatType, energyType
            ]
            
            var allSamples: [HKSample] = []
            let group = DispatchGroup()
            
            for type in types {
                group.enter()
                let predicate = HKQuery.predicateForObject(with: uuid)
                let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                    if let samples = samples {
                        allSamples.append(contentsOf: samples)
                    }
                    group.leave()
                }
                healthStore.execute(query)
            }
            
            group.notify(queue: .main) {
                completion(allSamples)
            }
        }
        
        private func performActualDeletion(samples: [HKSample], completion: @escaping (Bool, Error?) -> Void) {
            print("[HK] 🗑️ Intentando borrar \(samples.count) muestras...")
            
            // Intentar borrado individual primero
            if samples.count == 1 {
                healthStore.delete(samples.first!) { success, error in
                    print("[HK] Borrado individual: success=\(success), error=\(error?.localizedDescription ?? "nil")")
                    completion(success, error)
                }
            } else {
                // Borrado múltiple
                healthStore.delete(samples) { success, error in
                    print("[HK] Borrado múltiple: success=\(success), error=\(error?.localizedDescription ?? "nil")")
                    completion(success, error)
                }
            }
        }
        
        private func verifyAfterDeletion(uuid: UUID, completion: @escaping ([HKSample]) -> Void) {
            // Usar la misma lógica que verifyBeforeDeletion
            verifyBeforeDeletion(uuid: uuid, completion: completion)
        }
        
        // Verificar permisos de escritura
        func checkWritePermissions() {
            let types: Set<HKSampleType> = [
                HKCorrelationType.correlationType(forIdentifier: .food)!,
                proteinType, carbsType, fatType, energyType
            ]
            
            for type in types {
                let status = healthStore.authorizationStatus(for: type)
                let statusText = status == .notDetermined ? "No determinado" :
                               status == .sharingDenied ? "❌ DENEGADO" : "✅ Autorizado"
                print("[HK] 🔐 Permisos para \(type.identifier): \(statusText)")
            }
        }

        /// Deletes nutrition data saved by this app using the metadata `HKMetadataKeyFoodType` (e.g., "Tostada (60g)").
        /// - Parameters:
        ///   - foodName: Exact value used in metadata for `HKMetadataKeyFoodType` (e.g., "\(food.name) (\(Int(entry.grams))g)")
        ///   - around: Optional date to narrow the deletion window (helps avoid deleting multiple entries with the same name/grams). If provided, a ±windowMinutes predicate is added.
        ///   - windowMinutes: Minutes for the date window when `around` is provided. Default 5.
        ///   - completion: Returns (success, totalDeletedCount, error)
//        func deleteByFoodName(_ foodName: String, around: Date? = nil, windowMinutes: Int = 5, completion: @escaping (Bool, Int, Error?) -> Void) {
//            // Build metadata predicate for the exact FoodType value
//            let metaPredicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyFoodType, allowedValues: [foodName])
//
//            // Optionally limit to a small time window around the provided date
//            var predicates: [NSPredicate] = [metaPredicate]
//            if let date = around, windowMinutes > 0 {
//                let delta = TimeInterval(windowMinutes * 60)
//                let start = date.addingTimeInterval(-delta)
//                let end   = date.addingTimeInterval(+delta)
//                let datePredicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate, .strictEndDate])
//                predicates.append(datePredicate)
//            }
//
//            // Limit to data written by this app (avoid deleting entries from other sources)
//            let sourcePredicate = HKQuery.predicateForObjects(from: HKSource.default())
//            predicates.append(sourcePredicate)
//
//            let finalPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
//
//            // Types to delete: correlation .food + nutrient quantity types
//            var sampleTypes: [HKSampleType] = [proteinType, carbsType, fatType, energyType]
//            if let foodCorrelation = HKCorrelationType.correlationType(forIdentifier: .food) {
//                sampleTypes.insert(foodCorrelation, at: 0)
//            }
//
//            let group = DispatchGroup()
//            var overallSuccess = true
//            var totalDeleted = 0
//            var firstError: Error?
//
//            for type in sampleTypes {
//                group.enter()
//                self.healthStore.deleteObjects(of: type, predicate: finalPredicate) { success, count, error in
//                    print("[HK] 🗑️ deleteObjects(of: \(type.identifier)) → success=\(success) count=\(count) error=\(error?.localizedDescription ?? "nil")")
//                    overallSuccess = overallSuccess && success
//                    totalDeleted += count
//                    if firstError == nil, let error = error { firstError = error }
//                    group.leave()
//                }
//            }
//
//            group.notify(queue: .main) {
//                if totalDeleted == 0 && overallSuccess {
//                    // Consider no-op deletions as success but report 0
//                    print("[HK] ℹ️ No matching samples found for FoodType=\(foodName)")
//                }
//                completion(overallSuccess, totalDeleted, firstError)
//            }
//        }

        /// Deletes nutrition data saved by this app using the metadata `HKMetadataKeyFoodType` (e.g., "Tostada (60g)").
        /// - Parameters:
        ///   - foodName: Exact value used in metadata for `HKMetadataKeyFoodType` (e.g., "\(food.name) (\(Int(entry.grams))g)")
        ///   - around: Optional date to narrow the deletion window (helps avoid deleting multiple entries with the same name/grams). If provided, a ±windowMinutes predicate is added.
        ///   - windowMinutes: Minutes for the date window when `around` is provided. Default 5.
        ///   - completion: Returns (success, totalDeletedCount, error)
        func deleteByFoodName(_ foodName: String, around: Date? = nil, windowMinutes: Int = 5, completion: @escaping (Bool, Int, Error?) -> Void) {
            // Build metadata predicate for the exact FoodType value
            let metaPredicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyFoodType, allowedValues: [foodName])

            // Optionally limit to a small time window around the provided date
            var predicates: [NSPredicate] = [metaPredicate]
            if let date = around, windowMinutes > 0 {
                let delta = TimeInterval(windowMinutes * 60)
                let start = date.addingTimeInterval(-delta)
                let end   = date.addingTimeInterval(+delta)
                let datePredicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate, .strictEndDate])
                predicates.append(datePredicate)
            }

            // Limit to data written by this app (avoid deleting entries from other sources)
            let sourcePredicate = HKQuery.predicateForObjects(from: HKSource.default())
            predicates.append(sourcePredicate)

            let finalPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

            // Types to delete: correlation .food + nutrient quantity types
            var sampleTypes: [HKSampleType] = [proteinType, carbsType, fatType, energyType]
            if let foodCorrelation = HKCorrelationType.correlationType(forIdentifier: .food) {
                sampleTypes.insert(foodCorrelation, at: 0)
            }

            let group = DispatchGroup()
            var overallSuccess = true
            var totalDeleted = 0
            var firstError: Error?

            for type in sampleTypes {
                group.enter()
                self.healthStore.deleteObjects(of: type, predicate: finalPredicate) { success, count, error in
                    print("[HK] 🗑️ deleteObjects(of: \(type.identifier)) → success=\(success) count=\(count) error=\(error?.localizedDescription ?? "nil")")
                    overallSuccess = overallSuccess && success
                    totalDeleted += count
                    if firstError == nil, let error = error { firstError = error }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                if totalDeleted == 0 && overallSuccess {
                    // Consider no-op deletions as success but report 0
                    print("[HK] ℹ️ No matching samples found for FoodType=\(foodName)")
                }
                completion(overallSuccess, totalDeleted, firstError)
            }
        }

    /// Saves a grouped Food correlation with custom metadata applied to both the correlation and each nutrient sample.
    /// This overload lets callers pass SyncIdentifier/SyncVersion (or any other metadata) so the entry can be reliably deleted/updated later.
    func saveMealAsFoodCorrelation(date: Date,
                                   name: String,
                                   protein: Double,
                                   carbs: Double,
                                   fat: Double,
                                   kcal: Double,
                                   metadata: [String: Any],
                                   completion: ((Bool, UUID?, Error?) -> Void)? = nil) {
        let proteinUnit = HKUnit.gram()
        let carbsUnit = HKUnit.gram()
        let fatUnit = HKUnit.gram()
        let energyUnit = HKUnit.kilocalorie()

        // Build nutrient samples with the provided metadata on each sample
        let nutrientSamples: Set<HKSample> = [
            HKQuantitySample(type: proteinType, quantity: HKQuantity(unit: proteinUnit, doubleValue: max(protein, 0)), start: date, end: date, metadata: metadata),
            HKQuantitySample(type: carbsType,   quantity: HKQuantity(unit: carbsUnit,   doubleValue: max(carbs, 0)),   start: date, end: date, metadata: metadata),
            HKQuantitySample(type: fatType,     quantity: HKQuantity(unit: fatUnit,     doubleValue: max(fat, 0)),     start: date, end: date, metadata: metadata),
            HKQuantitySample(type: energyType,  quantity: HKQuantity(unit: energyUnit,  doubleValue: max(kcal, 0)),    start: date, end: date, metadata: metadata)
        ]

        if let foodType = HKCorrelationType.correlationType(forIdentifier: .food) {
            // Attach the same metadata to the correlation as well
            let correlation = HKCorrelation(type: foodType, start: date, end: date, objects: nutrientSamples, metadata: metadata)
            healthStore.save(correlation) { success, error in
                if success {
                    completion?(true, correlation.uuid, nil)
                } else {
                    // Fallback to saving raw samples if correlation fails
                    self.healthStore.save(Array(nutrientSamples)) { s, e in
                        completion?(s, (s ? Array(nutrientSamples).first?.uuid : nil), e)
                    }
                }
            }
        } else {
            // Very old systems without Food correlation support
            self.healthStore.save(Array(nutrientSamples)) { success, error in
                completion?(success, (success ? Array(nutrientSamples).first?.uuid : nil), error)
            }
        }
    }

    /// Convenience method with a distinct name to avoid overload resolution issues at call sites.
    /// Saves a .food correlation and nutrient samples with the provided metadata.
    func saveMealAsFoodCorrelationWithMetadata(date: Date,
                                               name: String,
                                               protein: Double,
                                               carbs: Double,
                                               fat: Double,
                                               kcal: Double,
                                               metadata: [String: Any],
                                               completion: ((Bool, UUID?, Error?) -> Void)? = nil) {
        saveMealAsFoodCorrelation(date: date,
                                  name: name,
                                  protein: protein,
                                  carbs: carbs,
                                  fat: fat,
                                  kcal: kcal,
                                  metadata: metadata,
                                  completion: completion)
    }
    
    func verifyDeletion(uuid: UUID) {
        let types: [HKSampleType?] = [
            HKCorrelationType.correlationType(forIdentifier: .food),
            proteinType, carbsType, fatType, energyType
        ]
        
        for case let type? in types {
            let predicate = HKQuery.predicateForObject(with: uuid)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, _ in
                print("[HK] Verificación - Tipo: \(type), muestras restantes: \(samples?.count ?? 0)")
            }
            healthStore.execute(query)
        }
    }
    
    func detailedVerification(uuid: UUID) {
        print("[HK] 🔍 VERIFICACIÓN DETALLADA para UUID: \(uuid)")
        
        // 1. Verificar por UUID exacto
        let types: [HKSampleType?] = [
            HKCorrelationType.correlationType(forIdentifier: .food),
            proteinType, carbsType, fatType, energyType
        ]
        
        let group = DispatchGroup()
        
        for case let type? in types {
            group.enter()
            
            let predicate = HKQuery.predicateForObject(with: uuid)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                
                let count = samples?.count ?? 0
                print("[HK] 📊 Tipo: \(type.identifier)")
                print("[HK]    └─ Por UUID: \(count) muestras")
                
                if let samples = samples, !samples.isEmpty {
                    for sample in samples {
                        print("[HK]       └─ Muestra encontrada: \(sample.uuid)")
                        print("[HK]          └─ Fuente: \(sample.sourceRevision.source.name)")
                        print("[HK]          └─ Fecha: \(sample.startDate)")
                    }
                }
                
                group.leave()
            }
            healthStore.execute(query)
        }
        
        // 2. También verificar datos recientes que podrían ser relacionados
        group.notify(queue: .main) {
            self.checkRecentFoodData(around: Date())
        }
    }

    func checkRecentFoodData(around date: Date) {
        print("[HK] 🔍 VERIFICANDO DATOS RECIENTES DE COMIDA...")
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let datePredicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: [])
        
        if let foodType = HKCorrelationType.correlationType(forIdentifier: .food) {
            let query = HKSampleQuery(sampleType: foodType, predicate: datePredicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, error in
                
                print("[HK] 📊 Correlaciones de comida del día: \(samples?.count ?? 0)")
                
                if let samples = samples {
                    for sample in samples {
                        if let correlation = sample as? HKCorrelation {
                            print("[HK] 🍽️ Comida encontrada:")
                            print("[HK]    └─ UUID: \(correlation.uuid)")
                            print("[HK]    └─ Fecha: \(correlation.startDate)")
                            print("[HK]    └─ Fuente: \(correlation.sourceRevision.source.name)")
                            print("[HK]    └─ Metadata: \(correlation.metadata ?? [:])")
                            print("[HK]    └─ Objetos: \(correlation.objects.count)")
                            
                            // Mostrar los objetos dentro de la correlación
                            for obj in correlation.objects {
                                if let quantity = obj as? HKQuantitySample {
                                    print("[HK]       └─ \(quantity.quantityType.identifier): \(quantity.quantity)")
                                }
                            }
                            print("[HK] ─────────────────")
                        }
                    }
                }
            }
            healthStore.execute(query)
        }
    }
    
    

    /// Deletes nutrition data using HKMetadataKeySyncIdentifier. This is the most reliable way to target a single entry.
    /// - Parameters:
    ///   - syncIdentifier: The exact value used when saving (HKMetadataKeySyncIdentifier)
    ///   - completion: (success, totalDeletedCount, error)
    func deleteBySyncIdentifier(_ syncIdentifier: String, completion: @escaping (Bool, Int, Error?) -> Void) {
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: [syncIdentifier])

        // Types to delete: correlation .food + nutrient quantity types
        var sampleTypes: [HKSampleType] = [proteinType, carbsType, fatType, energyType]
        if let foodCorrelation = HKCorrelationType.correlationType(forIdentifier: .food) {
            sampleTypes.insert(foodCorrelation, at: 0)
        }

        let group = DispatchGroup()
        var overallSuccess = true
        var totalDeleted = 0
        var firstError: Error?

        for type in sampleTypes {
            group.enter()
            self.healthStore.deleteObjects(of: type, predicate: predicate) { success, count, error in
                print("[HK] 🗑️ deleteBySyncIdentifier → type=\(type.identifier) success=\(success) count=\(count) error=\(error?.localizedDescription ?? "nil")")
                overallSuccess = overallSuccess && success
                totalDeleted += count
                if firstError == nil, let error = error { firstError = error }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if totalDeleted == 0 && overallSuccess {
                print("[HK] ℹ️ No matching samples found for SyncIdentifier=\(syncIdentifier)")
            }
            completion(overallSuccess, totalDeleted, firstError)
        }
    }

    
    // Puedes llamar a esta función pasando el tipo correcto (ejemplo: correlationType forIdentifier: .food) y el UUID que guardaste.
}


    
