import Foundation

struct NutritionEntry: Codable, Identifiable {
    var id: String
    var userId: String
    var date: Date
    var foodName: String
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var mealType: MealType
    var servingSize: Double?   // amount in servingUnit (nil = unspecified)
    var servingUnit: String?   // "g", "ml", "piece" — nil for manual entries

    // Custom decoder so entries saved before servingSize was added still decode correctly.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self,    forKey: .id)
        userId      = try c.decode(String.self,    forKey: .userId)
        date        = try c.decode(Date.self,      forKey: .date)
        foodName    = try c.decode(String.self,    forKey: .foodName)
        calories    = try c.decode(Double.self,    forKey: .calories)
        proteinG    = try c.decode(Double.self,    forKey: .proteinG)
        carbsG      = try c.decode(Double.self,    forKey: .carbsG)
        fatG        = try c.decode(Double.self,    forKey: .fatG)
        mealType    = try c.decode(MealType.self,  forKey: .mealType)
        servingSize = try c.decodeIfPresent(Double.self,  forKey: .servingSize)
        servingUnit = try c.decodeIfPresent(String.self,  forKey: .servingUnit)
    }

    // Memberwise init required alongside custom decoder.
    init(id: String, userId: String, date: Date, foodName: String,
         calories: Double, proteinG: Double, carbsG: Double, fatG: Double,
         mealType: MealType, servingSize: Double? = nil, servingUnit: String? = nil) {
        self.id          = id
        self.userId      = userId
        self.date        = date
        self.foodName    = foodName
        self.calories    = calories
        self.proteinG    = proteinG
        self.carbsG      = carbsG
        self.fatG        = fatG
        self.mealType    = mealType
        self.servingSize = servingSize
        self.servingUnit = servingUnit
    }

    static func new(userId: String, foodName: String,
                    calories: Double, protein: Double, carbs: Double, fat: Double,
                    meal: MealType,
                    servingSize: Double? = nil, servingUnit: String? = nil) -> NutritionEntry {
        NutritionEntry(
            id: UUID().uuidString, userId: userId, date: Date(),
            foodName: foodName, calories: calories,
            proteinG: protein, carbsG: carbs, fatG: fat, mealType: meal,
            servingSize: servingSize, servingUnit: servingUnit
        )
    }

    var servingLabel: String? {
        guard let size = servingSize, let unit = servingUnit else { return nil }
        let s = size.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(size))" : String(format: "%.1f", size)
        return "\(s) \(unit)"
    }
}

enum MealType: String, Codable, CaseIterable, Identifiable, Hashable {
    case breakfast = "Breakfast"
    case lunch     = "Lunch"
    case dinner    = "Dinner"
    case snack     = "Snack"
    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .breakfast: return "sun.rise"
        case .lunch:     return "sun.max"
        case .dinner:    return "moon"
        case .snack:     return "leaf"
        }
    }
}

struct WaterEntry: Codable, Identifiable {
    var id: String
    var userId: String
    var date: Date
    var amountMl: Double

    static func new(userId: String, ml: Double) -> WaterEntry {
        WaterEntry(id: UUID().uuidString, userId: userId, date: Date(), amountMl: ml)
    }
}
