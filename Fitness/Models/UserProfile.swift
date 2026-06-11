import Foundation

// MARK: - UserProfile

struct UserProfile: Codable, Identifiable {
    var id: String
    var email: String
    var displayName: String
    var age: Int
    var weightKg: Double
    var heightCm: Double
    var sex: BiologicalSex
    var activityLevel: ActivityLevel
    var fitnessGoal: FitnessGoal
    var workoutFocus: WorkoutFocus
    var workoutMinutes: Int
    var joinedDate: Date
    var experienceLevel: ExperienceLevel = .beginner
    var availableEquipment: [Equipment] = [.bodyweight]

    // MARK: Mifflin-St Jeor BMR
    // Formula: (10 × weight_kg) + (6.25 × height_cm) − (5 × age) + sex_constant
    // Male: +5  |  Female: −161  |  Other: midpoint −78
    var bmr: Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        switch sex {
        case .male:   return base + 5
        case .female: return base - 161
        case .other:  return base - 78
        }
    }

    // MARK: TDEE — BMR × activity multiplier
    var tdee: Double { bmr * activityLevel.multiplier }

    // MARK: Recommended daily calorie intake
    // Applies a deficit or surplus to TDEE, then clamps to the minimum safe floor for the sex.
    var recommendedDailyCalories: Double {
        let adjusted = tdee + fitnessGoal.calorieAdjustment
        return max(adjusted, minimumSafeIntake)
    }

    // MARK: Active calorie goal (exercise ring target)
    // Fraction of TDEE to burn through intentional exercise, scaled by goal.
    var computedActiveCalorieGoal: Double {
        let fraction = fitnessGoal.activeCalorieFraction
        return max(tdee * fraction, fitnessGoal.activeCalorieFloor)
    }

    // MARK: Macro targets derived from recommendedDailyCalories
    var macroTargets: MacroTargets {
        MacroTargets.compute(calories: recommendedDailyCalories, goal: fitnessGoal)
    }

    // MARK: - Helpers

    var calorieAdjustmentLabel: String {
        let adj = Int(fitnessGoal.calorieAdjustment)
        let clamped = Int(recommendedDailyCalories - tdee)
        if clamped != adj {
            return "Floor applied — safe minimum"
        }
        return adj == 0 ? "Maintenance" : (adj > 0 ? "+\(adj) kcal surplus" : "\(adj) kcal deficit")
    }

    private var minimumSafeIntake: Double {
        switch sex {
        case .female: return 1_200
        case .male:   return 1_500
        case .other:  return 1_350
        }
    }

    // MARK: Placeholder

    static func placeholder(id: String, email: String) -> UserProfile {
        UserProfile(
            id: id, email: email, displayName: "",
            age: 30, weightKg: 70, heightCm: 170,
            sex: .male, activityLevel: .moderatelyActive,
            fitnessGoal: .fatLoss, workoutFocus: .balanced,
            workoutMinutes: 30, joinedDate: Date(),
            experienceLevel: .beginner, availableEquipment: [.bodyweight]
        )
    }
}

// MARK: - MacroTargets

struct MacroTargets {
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let calories: Double

    var proteinKcal: Double { proteinG * 4 }
    var carbsKcal: Double   { carbsG  * 4 }
    var fatKcal: Double     { fatG    * 9 }

    /// Percentages used for the donut chart (already stored as fractions of calories).
    var proteinFraction: Double { calories > 0 ? proteinKcal / calories : 0.33 }
    var carbsFraction: Double   { calories > 0 ? carbsKcal   / calories : 0.33 }
    var fatFraction: Double     { calories > 0 ? fatKcal     / calories : 0.34 }

    // Macro ratios by goal (protein% / carbs% / fat%)
    // All values are % of total calories; fat converted via ÷9, others ÷4.
    static func compute(calories: Double, goal: FitnessGoal) -> MacroTargets {
        let (pPct, cPct, fPct): (Double, Double, Double)
        switch goal {
        case .fatLoss:     (pPct, cPct, fPct) = (0.40, 0.30, 0.30) // high protein
        case .maintenance: (pPct, cPct, fPct) = (0.30, 0.40, 0.30) // balanced
        case .strength:    (pPct, cPct, fPct) = (0.35, 0.40, 0.25) // muscle-building
        case .endurance:   (pPct, cPct, fPct) = (0.25, 0.50, 0.25) // carb-fuelled
        }
        return MacroTargets(
            proteinG: calories * pPct / 4,
            carbsG:   calories * cPct / 4,
            fatG:     calories * fPct / 9,
            calories: calories
        )
    }
}

// MARK: - Enums

enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
    case male = "Male", female = "Female", other = "Other"
    var id: String { rawValue }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary         = "Sedentary"
    case lightlyActive     = "Lightly Active"
    case moderatelyActive  = "Moderately Active"
    case veryActive        = "Very Active"
    case extraActive       = "Extra Active"
    var id: String { rawValue }

    /// Harris-Benedict / Mifflin-St Jeor standard PAL values
    var multiplier: Double {
        switch self {
        case .sedentary:        return 1.2
        case .lightlyActive:    return 1.375
        case .moderatelyActive: return 1.55
        case .veryActive:       return 1.725
        case .extraActive:      return 1.9
        }
    }

    var description: String {
        switch self {
        case .sedentary:        return "Desk job, little or no exercise"
        case .lightlyActive:    return "Light exercise 1–3 days/week"
        case .moderatelyActive: return "Moderate exercise 3–5 days/week"
        case .veryActive:       return "Hard exercise 6–7 days/week"
        case .extraActive:      return "Physical job + daily training"
        }
    }
}

enum FitnessGoal: String, Codable, CaseIterable, Identifiable, Hashable {
    case fatLoss     = "Fat Loss"
    case maintenance = "Maintain"
    case strength    = "Strength"
    case endurance   = "Endurance"
    var id: String { rawValue }

    /// Net kcal adjustment applied to TDEE to get daily dietary target.
    /// Fat loss = −500 kcal/day ≈ 0.5 kg/week deficit.
    var calorieAdjustment: Double {
        switch self {
        case .fatLoss:     return -500
        case .maintenance: return    0
        case .strength:    return +300   // lean bulk
        case .endurance:   return +200   // performance fuel
        }
    }

    var activeCalorieFraction: Double {
        switch self {
        case .fatLoss:     return 0.25
        case .maintenance: return 0.20
        case .strength:    return 0.18
        case .endurance:   return 0.30
        }
    }

    var activeCalorieFloor: Double {
        switch self {
        case .fatLoss:     return 400
        case .maintenance: return 300
        case .strength:    return 350
        case .endurance:   return 450
        }
    }

    var adjustmentLabel: String {
        let adj = Int(calorieAdjustment)
        return adj == 0 ? "Maintain" : (adj > 0 ? "+\(adj) kcal" : "\(adj) kcal")
    }
}

enum WorkoutFocus: String, Codable, CaseIterable, Identifiable {
    case balanced  = "Balanced"
    case lowImpact = "Low Impact"
    case strength  = "Strength"
    case cardio    = "Cardio"
    case mobility  = "Mobility"
    var id: String { rawValue }
}
