import HealthKit
import Foundation

// MARK: - HealthKitService

@MainActor
final class HealthKitService: ObservableObject {

    // MARK: - Published state

    @Published var activeEnergyToday: Double = 0   // kcal
    @Published var stepsToday: Int = 0
    @Published var restingHeartRate: Double = 0    // bpm (latest sample)
    @Published var heartRateToday: Double = 0      // bpm (day average)
    @Published var waterMlToday: Double = 0        // ml
    @Published var workoutMinutesToday: Int = 0
    @Published var workoutCountToday: Int = 0
    @Published var authorizationState: HealthAuthorizationState = .notRequested
    @Published var statusMessage = "Connect Apple Health to sync your data."

    /// Called on the main actor after every `refreshAll()` finishes.
    var onDataRefreshed: (() -> Void)?

    // MARK: - Private

    private let store = HKHealthStore()
    private var observers: [HKObserverQuery] = []
    private var isRefreshing = false

    private static let authorizedKey = "fitsight.hk.authorized"

    // MARK: - Init

    init() {
        if UserDefaults.standard.bool(forKey: Self.authorizedKey),
           HKHealthStore.isHealthDataAvailable() {
            authorizationState = .authorized
            statusMessage = "Connected — syncing activity data."
            startObservers()
            Task { await refreshAll() }
        }
    }

    // MARK: - Read types

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        let quantityIds: [HKQuantityTypeIdentifier] = [
            .activeEnergyBurned, .stepCount, .restingHeartRate, .heartRate, .dietaryWater,
        ]
        for id in quantityIds {
            if let t = HKQuantityType.quantityType(forIdentifier: id) { types.insert(t) }
        }
        types.insert(HKObjectType.workoutType())
        return types
    }

    private var observedQuantityTypes: [HKQuantityType] {
        [.activeEnergyBurned, .stepCount, .heartRate, .dietaryWater]
            .compactMap { HKQuantityType.quantityType(forIdentifier: $0) }
    }

    // MARK: - Authorization

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationState = .unavailable
            statusMessage = "Apple Health is not available on this device."
            return
        }
        store.requestAuthorization(toShare: [], read: readTypes) { [weak self] success, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if success {
                    UserDefaults.standard.set(true, forKey: Self.authorizedKey)
                    authorizationState = .authorized
                    statusMessage = "Connected — syncing activity data."
                    startObservers()
                    await refreshAll()
                } else {
                    authorizationState = .denied
                    statusMessage = deniedMessage(error: error)
                }
            }
        }
    }

    private func deniedMessage(error: Error?) -> String {
        if let msg = error?.localizedDescription { return "Health sync error: \(msg)" }
        return "Health access was not granted. Go to Settings → Privacy & Security → Health → FitSight to enable access."
    }

    // MARK: - Background observers

    func startObservers() {
        stopObservers()
        for type in observedQuantityTypes {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completionHandler, error in
                defer { completionHandler() }
                guard error == nil else { return }
                Task { @MainActor [weak self] in await self?.refreshAll() }
            }
            store.execute(query)
            observers.append(query)

            let frequency: HKUpdateFrequency =
                type.identifier == HKQuantityTypeIdentifier.activeEnergyBurned.rawValue
                    ? .immediate : .hourly
            store.enableBackgroundDelivery(for: type, frequency: frequency) { _, _ in }
        }
    }

    func stopObservers() {
        observers.forEach { store.stop($0) }
        observers.removeAll()
    }

    // MARK: - Data refresh

    /// Fires all six HK queries in parallel via async let, then applies results on MainActor.
    func refreshAll() async {
        guard HKHealthStore.isHealthDataAvailable(), !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        // kcal unit note:
        //  • HKUnit.kilocalorie() == "kcal" — the food/fitness calorie shown in Activity.app
        //  • HKUnit.smallCalorie() == "cal" — 1/1000 kcal; do NOT use for energy
        let kcal = HKUnit.kilocalorie()
        let ml   = HKUnit.literUnit(with: .milli)
        let bpm  = HKUnit.count().unitDivided(by: .minute())

        async let energy   = fetchDaySum(.activeEnergyBurned, unit: kcal)
        async let steps    = fetchDaySum(.stepCount, unit: .count())
        async let water    = fetchDaySum(.dietaryWater, unit: ml)
        async let rhr      = fetchLatestSample(.restingHeartRate, unit: bpm)
        async let avgHR    = fetchDayAverage(.heartRate, unit: bpm)
        async let workouts = fetchTodayWorkouts()

        let (e, s, w, r, h, wrk) = await (energy, steps, water, rhr, avgHR, workouts)

        activeEnergyToday   = e
        stepsToday          = Int(s)
        waterMlToday        = w
        restingHeartRate    = r
        heartRateToday      = h
        workoutMinutesToday = wrk.minutes
        workoutCountToday   = wrk.count
        onDataRefreshed?()
    }

    // MARK: - Weekly chart data

    /// Runs all 7 daily energy queries concurrently via withTaskGroup.
    func weeklyActiveEnergy() async -> [DailyMetric] {
        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        else { return placeholderMetrics() }

        let calendar  = Calendar.current
        let today     = calendar.startOfDay(for: Date())
        let formatter = DateFormatter(); formatter.dateFormat = "EEE"

        struct DaySlot { let offset: Int; let start: Date; let end: Date; let label: String }
        let slots: [DaySlot] = (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today),
                  let end = calendar.date(byAdding: .day, value: 1, to: day)
            else { return nil }
            return DaySlot(offset: offset, start: day, end: end, label: formatter.string(from: day))
        }

        return await withTaskGroup(of: (Int, DailyMetric).self) { group in
            for slot in slots {
                // Capture Sendable Date values; build NSPredicate inside the task
                // so it is never passed across a concurrency boundary.
                let start  = slot.start
                let end    = slot.end
                let label  = slot.label
                let offset = slot.offset
                group.addTask { [self] in
                    let value = await fetchActiveEnergySum(type: type, start: start, end: end)
                    return (offset, DailyMetric(day: label, value: value))
                }
            }
            var results: [(Int, DailyMetric)] = []
            for await pair in group { results.append(pair) }
            // Sort descending by offset so oldest day (highest offset) comes first.
            return results.sorted { $0.0 > $1.0 }.map(\.1)
        }
    }

    private func placeholderMetrics() -> [DailyMetric] {
        let formatter = DateFormatter(); formatter.dateFormat = "EEE"
        let calendar  = Calendar.current
        let today     = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).map {
                DailyMetric(day: formatter.string(from: $0), value: 0)
            }
        }
    }

    // MARK: - Query helpers

    private func fetchDaySum(_ id: HKQuantityTypeIdentifier,
                                         unit: HKUnit) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return 0 }
        let start     = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let q = HKStatisticsQuery(quantityType: type,
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, stats, _ in
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(q)
        }
    }

    private func fetchDayAverage(_ id: HKQuantityTypeIdentifier,
                                              unit: HKUnit) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return 0 }
        let start     = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let q = HKStatisticsQuery(quantityType: type,
                                      quantitySamplePredicate: predicate,
                                      options: .discreteAverage) { _, stats, _ in
                continuation.resume(returning: stats?.averageQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(q)
        }
    }

    private func fetchLatestSample(_ id: HKQuantityTypeIdentifier,
                                               unit: HKUnit) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return 0 }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let val = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit) ?? 0
                continuation.resume(returning: val)
            }
            store.execute(q)
        }
    }

    private func fetchTodayWorkouts() async -> (minutes: Int, count: Int) {
        let start     = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let q = HKSampleQuery(sampleType: .workoutType(),
                                  predicate: predicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: nil) { _, samples, _ in
                let workouts     = samples as? [HKWorkout] ?? []
                let totalMinutes = Int(workouts.reduce(0.0) { $0 + $1.duration } / 60)
                continuation.resume(returning: (minutes: totalMinutes, count: workouts.count))
            }
            store.execute(q)
        }
    }

    private func fetchActiveEnergySum(type: HKQuantityType,
                                       start: Date, end: Date) async -> Double {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let q = HKStatisticsQuery(quantityType: type,
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, stats, _ in
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0)
            }
            store.execute(q)
        }
    }
}
