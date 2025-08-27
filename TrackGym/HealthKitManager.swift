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
    func saveMealAsFoodCorrelation(date: Date, name: String, protein: Double, carbs: Double, fat: Double, kcal: Double, completion: ((Bool, Error?) -> Void)? = nil) {
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
                if !success {
                    // Fallback to saving raw samples if correlation fails
                    self.healthStore.save(Array(nutrientSamples)) { s, e in
                        completion?(s, e)
                    }
                } else {
                    completion?(success, error)
                }
            }
        } else {
            // Very old systems without Food correlation support
            healthStore.save(Array(nutrientSamples)) { success, error in
                completion?(success, error)
            }
        }
    }
}
