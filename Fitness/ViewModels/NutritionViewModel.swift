import Foundation
import SwiftUI

@MainActor
final class NutritionViewModel: ObservableObject {
    @Published var todayEntries: [NutritionEntry] = []
    @Published var waterEntriesML: Double = 0
    @Published var isLoading = false

    var macroTargets: MacroTargets?
    var waterGoalMl: Double = 2000

    private let db: any DatabaseServiceProtocol
    init(db: any DatabaseServiceProtocol) { self.db = db }

    // MARK: - Calorie / macro totals

    var totalCaloriesToday: Double { todayEntries.map(\.calories).reduce(0, +) }
    var totalProteinG: Double      { todayEntries.map(\.proteinG).reduce(0, +) }
    var totalCarbsG: Double        { todayEntries.map(\.carbsG).reduce(0, +)   }
    var totalFatG: Double          { todayEntries.map(\.fatG).reduce(0, +)     }

    // MARK: - Water

    var waterProgressFraction: Double { min(waterEntriesML / waterGoalMl, 1.0) }
    var waterCups: Int { Int(waterEntriesML / 250) }

    // MARK: - Macro progress vs goals (0–1 fractions)

    var proteinProgress: Double {
        guard let t = macroTargets, t.proteinG > 0 else { return 0 }
        return min(totalProteinG / t.proteinG, 1)
    }
    var carbsProgress: Double {
        guard let t = macroTargets, t.carbsG > 0 else { return 0 }
        return min(totalCarbsG / t.carbsG, 1)
    }
    var fatProgress: Double {
        guard let t = macroTargets, t.fatG > 0 else { return 0 }
        return min(totalFatG / t.fatG, 1)
    }

    // MARK: - Grouped by meal

    var entriesByMeal: [(MealType, [NutritionEntry])] {
        MealType.allCases.compactMap { meal in
            let items = todayEntries.filter { $0.mealType == meal }
            return items.isEmpty ? nil : (meal, items)
        }
    }

    // MARK: - Load

    func loadToday(uid: String) async {
        isLoading = true
        defer { isLoading = false }
        todayEntries    = (try? await db.fetchNutritionEntries(uid: uid, date: Date())) ?? []
        let waters      = (try? await db.fetchWaterEntries(uid: uid, date: Date())) ?? []
        waterEntriesML  = waters.map(\.amountMl).reduce(0, +)
    }

    // MARK: - Food entries

    func addEntry(_ entry: NutritionEntry) async {
        try? await db.saveNutritionEntry(entry)
        todayEntries.append(entry)
    }

    func removeEntry(_ entry: NutritionEntry, uid: String) async {
        todayEntries.removeAll { $0.id == entry.id }
        for e in todayEntries { try? await db.saveNutritionEntry(e) }
    }

    // MARK: - Water

    func logWater(ml: Double, uid: String) async {
        let entry = WaterEntry.new(userId: uid, ml: ml)
        try? await db.saveWaterEntry(entry)
        waterEntriesML += ml
    }

    func resetWater(uid: String) async {
        waterEntriesML = 0
        // Save an empty water list by overwriting stored key via a sentinel 0ml entry
        // (DatabaseService stores all entries and we filter by date, so write an empty array)
        let key = "water.\(uid)"
        UserDefaults.standard.removeObject(forKey: "fitsight.\(key)")
    }
}
