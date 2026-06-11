import Foundation

// MARK: - Food preset

struct FoodPreset: Identifiable {
    let id: String
    let name: String
    let category: FoodCategory
    let calories100g: Double
    let protein100g: Double
    let carbs100g: Double
    let fat100g: Double
    let defaultServingG: Double
    let servingUnit: String

    func entry(userId: String, meal: MealType, servingG: Double) -> NutritionEntry {
        let m = servingG / 100.0
        return NutritionEntry.new(
            userId: userId,
            foodName: name,
            calories: (calories100g * m).rounded(),
            protein: (protein100g * m).rounded(to: 1),
            carbs: (carbs100g * m).rounded(to: 1),
            fat: (fat100g * m).rounded(to: 1),
            meal: meal,
            servingSize: servingG,
            servingUnit: servingUnit
        )
    }
}

enum FoodCategory: String, CaseIterable {
    case protein     = "Protein"
    case grains      = "Grains"
    case dairy       = "Dairy"
    case vegetables  = "Vegetables"
    case fruits      = "Fruits"
    case fats        = "Fats & Nuts"
    case beverages   = "Beverages"
    case meals       = "Quick Meals"

    var symbolName: String {
        switch self {
        case .protein:    return "fork.knife"
        case .grains:     return "leaf.arrow.circlepath"
        case .dairy:      return "cup.and.saucer"
        case .vegetables: return "carrot"
        case .fruits:     return "applelogo"
        case .fats:       return "circle.hexagongrid"
        case .beverages:  return "drop.fill"
        case .meals:      return "takeoutbag.and.cup.and.straw"
        }
    }
}

// MARK: - Food database

enum FoodDatabase {

    static let all: [FoodPreset] = proteins + grains + dairy + vegetables + fruits + fats + beverages + meals

    static func search(_ query: String) -> [FoodPreset] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return all }
        let q = query.lowercased()
        return all.filter {
            $0.name.lowercased().contains(q) || $0.category.rawValue.lowercased().contains(q)
        }
    }

    // MARK: - Protein sources (per 100 g cooked unless stated)

    private static let proteins: [FoodPreset] = [
        FoodPreset(id: "chicken_breast",   name: "Chicken Breast",     category: .protein, calories100g: 165, protein100g: 31,   carbs100g: 0,    fat100g: 3.6,  defaultServingG: 150, servingUnit: "g"),
        FoodPreset(id: "turkey_breast",    name: "Turkey Breast",      category: .protein, calories100g: 135, protein100g: 30,   carbs100g: 0,    fat100g: 1.5,  defaultServingG: 150, servingUnit: "g"),
        FoodPreset(id: "salmon",           name: "Salmon",             category: .protein, calories100g: 208, protein100g: 20,   carbs100g: 0,    fat100g: 13,   defaultServingG: 150, servingUnit: "g"),
        FoodPreset(id: "tuna_canned",      name: "Tuna (canned)",      category: .protein, calories100g: 116, protein100g: 26,   carbs100g: 0,    fat100g: 0.9,  defaultServingG: 85,  servingUnit: "g"),
        FoodPreset(id: "beef_lean",        name: "Lean Beef",          category: .protein, calories100g: 215, protein100g: 26,   carbs100g: 0,    fat100g: 12,   defaultServingG: 150, servingUnit: "g"),
        FoodPreset(id: "pork_loin",        name: "Pork Loin",          category: .protein, calories100g: 143, protein100g: 26,   carbs100g: 0,    fat100g: 3.5,  defaultServingG: 150, servingUnit: "g"),
        FoodPreset(id: "shrimp",           name: "Shrimp",             category: .protein, calories100g: 99,  protein100g: 24,   carbs100g: 0.2,  fat100g: 0.3,  defaultServingG: 100, servingUnit: "g"),
        FoodPreset(id: "eggs",             name: "Eggs",               category: .protein, calories100g: 155, protein100g: 13,   carbs100g: 1.1,  fat100g: 11,   defaultServingG: 100, servingUnit: "g"),
        FoodPreset(id: "egg_whites",       name: "Egg Whites",         category: .protein, calories100g: 52,  protein100g: 11,   carbs100g: 0.7,  fat100g: 0.2,  defaultServingG: 100, servingUnit: "g"),
        FoodPreset(id: "tofu_firm",        name: "Tofu (firm)",        category: .protein, calories100g: 76,  protein100g: 8,    carbs100g: 2,    fat100g: 4.2,  defaultServingG: 150, servingUnit: "g"),
        FoodPreset(id: "edamame",          name: "Edamame",            category: .protein, calories100g: 121, protein100g: 11,   carbs100g: 9,    fat100g: 5,    defaultServingG: 100, servingUnit: "g"),
        FoodPreset(id: "lentils",          name: "Lentils (cooked)",   category: .protein, calories100g: 116, protein100g: 9,    carbs100g: 20,   fat100g: 0.4,  defaultServingG: 150, servingUnit: "g"),
        FoodPreset(id: "black_beans",      name: "Black Beans",        category: .protein, calories100g: 132, protein100g: 8.9,  carbs100g: 24,   fat100g: 0.5,  defaultServingG: 150, servingUnit: "g"),
        FoodPreset(id: "chickpeas",        name: "Chickpeas",          category: .protein, calories100g: 164, protein100g: 8.9,  carbs100g: 27,   fat100g: 2.6,  defaultServingG: 150, servingUnit: "g"),
        FoodPreset(id: "whey_protein",     name: "Whey Protein",       category: .protein, calories100g: 400, protein100g: 80,   carbs100g: 8,    fat100g: 5,    defaultServingG: 30,  servingUnit: "g"),
        FoodPreset(id: "greek_yogurt",     name: "Greek Yogurt (0%)",  category: .protein, calories100g: 59,  protein100g: 10,   carbs100g: 3.6,  fat100g: 0.4,  defaultServingG: 200, servingUnit: "g"),
        FoodPreset(id: "cottage_cheese",   name: "Cottage Cheese",     category: .protein, calories100g: 98,  protein100g: 11,   carbs100g: 3.4,  fat100g: 4.3,  defaultServingG: 150, servingUnit: "g"),
    ]

    // MARK: - Grains (per 100 g cooked unless stated)

    private static let grains: [FoodPreset] = [
        FoodPreset(id: "oats_dry",       name: "Oats (dry)",          category: .grains, calories100g: 389, protein100g: 17,  carbs100g: 66, fat100g: 7,   defaultServingG: 50,  servingUnit: "g"),
        FoodPreset(id: "white_rice",     name: "White Rice (cooked)", category: .grains, calories100g: 130, protein100g: 2.7, carbs100g: 28, fat100g: 0.3, defaultServingG: 150, servingUnit: "g"),
        FoodPreset(id: "brown_rice",     name: "Brown Rice (cooked)", category: .grains, calories100g: 123, protein100g: 2.7, carbs100g: 26, fat100g: 1,   defaultServingG: 150, servingUnit: "g"),
        FoodPreset(id: "pasta",          name: "Pasta (cooked)",      category: .grains, calories100g: 131, protein100g: 5,   carbs100g: 25, fat100g: 1.1, defaultServingG: 200, servingUnit: "g"),
        FoodPreset(id: "quinoa",         name: "Quinoa (cooked)",     category: .grains, calories100g: 120, protein100g: 4.4, carbs100g: 22, fat100g: 1.9, defaultServingG: 150, servingUnit: "g"),
        FoodPreset(id: "sweet_potato",   name: "Sweet Potato",        category: .grains, calories100g: 86,  protein100g: 1.6, carbs100g: 20, fat100g: 0.1, defaultServingG: 150, servingUnit: "g"),
        FoodPreset(id: "potato",         name: "Potato (baked)",      category: .grains, calories100g: 93,  protein100g: 2.5, carbs100g: 21, fat100g: 0.1, defaultServingG: 180, servingUnit: "g"),
        FoodPreset(id: "whole_wheat_bread", name: "Whole Wheat Bread", category: .grains, calories100g: 247, protein100g: 13, carbs100g: 41, fat100g: 4.2, defaultServingG: 40,  servingUnit: "g"),
        FoodPreset(id: "white_bread",    name: "White Bread",         category: .grains, calories100g: 265, protein100g: 9,   carbs100g: 49, fat100g: 3.2, defaultServingG: 40,  servingUnit: "g"),
        FoodPreset(id: "tortilla",       name: "Corn Tortilla",       category: .grains, calories100g: 218, protein100g: 5.7, carbs100g: 46, fat100g: 2.5, defaultServingG: 45,  servingUnit: "g"),
    ]

    // MARK: - Dairy

    private static let dairy: [FoodPreset] = [
        FoodPreset(id: "whole_milk",    name: "Whole Milk",     category: .dairy, calories100g: 61,  protein100g: 3.2, carbs100g: 4.8, fat100g: 3.3, defaultServingG: 240, servingUnit: "ml"),
        FoodPreset(id: "skim_milk",     name: "Skim Milk",      category: .dairy, calories100g: 34,  protein100g: 3.4, carbs100g: 4.9, fat100g: 0.1, defaultServingG: 240, servingUnit: "ml"),
        FoodPreset(id: "cheddar",       name: "Cheddar Cheese", category: .dairy, calories100g: 402, protein100g: 25,  carbs100g: 1.3, fat100g: 33,  defaultServingG: 30,  servingUnit: "g"),
        FoodPreset(id: "mozzarella",    name: "Mozzarella",     category: .dairy, calories100g: 280, protein100g: 22,  carbs100g: 2.2, fat100g: 17,  defaultServingG: 30,  servingUnit: "g"),
        FoodPreset(id: "butter",        name: "Butter",         category: .dairy, calories100g: 717, protein100g: 0.9, carbs100g: 0.1, fat100g: 81,  defaultServingG: 14,  servingUnit: "g"),
        FoodPreset(id: "cream_cheese",  name: "Cream Cheese",   category: .dairy, calories100g: 342, protein100g: 6,   carbs100g: 4.1, fat100g: 34,  defaultServingG: 30,  servingUnit: "g"),
    ]

    // MARK: - Vegetables

    private static let vegetables: [FoodPreset] = [
        FoodPreset(id: "broccoli",    name: "Broccoli",       category: .vegetables, calories100g: 34, protein100g: 2.8, carbs100g: 6.6, fat100g: 0.4, defaultServingG: 150, servingUnit: "g"),
        FoodPreset(id: "spinach",     name: "Spinach",        category: .vegetables, calories100g: 23, protein100g: 2.9, carbs100g: 3.6, fat100g: 0.4, defaultServingG: 100, servingUnit: "g"),
        FoodPreset(id: "avocado",     name: "Avocado",        category: .vegetables, calories100g: 160, protein100g: 2,  carbs100g: 9,   fat100g: 15,  defaultServingG: 100, servingUnit: "g"),
        FoodPreset(id: "carrot",      name: "Carrot",         category: .vegetables, calories100g: 41, protein100g: 0.9, carbs100g: 10,  fat100g: 0.2, defaultServingG: 100, servingUnit: "g"),
        FoodPreset(id: "bell_pepper", name: "Bell Pepper",    category: .vegetables, calories100g: 31, protein100g: 1,   carbs100g: 6,   fat100g: 0.3, defaultServingG: 120, servingUnit: "g"),
        FoodPreset(id: "cucumber",    name: "Cucumber",       category: .vegetables, calories100g: 16, protein100g: 0.7, carbs100g: 3.6, fat100g: 0.1, defaultServingG: 100, servingUnit: "g"),
        FoodPreset(id: "tomato",      name: "Tomato",         category: .vegetables, calories100g: 18, protein100g: 0.9, carbs100g: 3.9, fat100g: 0.2, defaultServingG: 120, servingUnit: "g"),
        FoodPreset(id: "salad_greens", name: "Mixed Salad",   category: .vegetables, calories100g: 20, protein100g: 1.8, carbs100g: 3.5, fat100g: 0.2, defaultServingG: 80,  servingUnit: "g"),
        FoodPreset(id: "kale",        name: "Kale",           category: .vegetables, calories100g: 49, protein100g: 4.3, carbs100g: 9,   fat100g: 0.9, defaultServingG: 80,  servingUnit: "g"),
    ]

    // MARK: - Fruits

    private static let fruits: [FoodPreset] = [
        FoodPreset(id: "banana",      name: "Banana",      category: .fruits, calories100g: 89,  protein100g: 1.1, carbs100g: 23, fat100g: 0.3, defaultServingG: 120, servingUnit: "g"),
        FoodPreset(id: "apple",       name: "Apple",       category: .fruits, calories100g: 52,  protein100g: 0.3, carbs100g: 14, fat100g: 0.2, defaultServingG: 182, servingUnit: "g"),
        FoodPreset(id: "orange",      name: "Orange",      category: .fruits, calories100g: 47,  protein100g: 0.9, carbs100g: 12, fat100g: 0.1, defaultServingG: 131, servingUnit: "g"),
        FoodPreset(id: "blueberries", name: "Blueberries", category: .fruits, calories100g: 57,  protein100g: 0.7, carbs100g: 14, fat100g: 0.3, defaultServingG: 100, servingUnit: "g"),
        FoodPreset(id: "strawberries", name: "Strawberries", category: .fruits, calories100g: 32, protein100g: 0.7, carbs100g: 7.7, fat100g: 0.3, defaultServingG: 150, servingUnit: "g"),
        FoodPreset(id: "mango",       name: "Mango",       category: .fruits, calories100g: 60,  protein100g: 0.8, carbs100g: 15, fat100g: 0.4, defaultServingG: 165, servingUnit: "g"),
        FoodPreset(id: "grapes",      name: "Grapes",      category: .fruits, calories100g: 67,  protein100g: 0.6, carbs100g: 17, fat100g: 0.4, defaultServingG: 150, servingUnit: "g"),
    ]

    // MARK: - Fats & nuts (per 100 g)

    private static let fats: [FoodPreset] = [
        FoodPreset(id: "almonds",      name: "Almonds",       category: .fats, calories100g: 579, protein100g: 21, carbs100g: 22, fat100g: 50, defaultServingG: 30,  servingUnit: "g"),
        FoodPreset(id: "walnuts",      name: "Walnuts",       category: .fats, calories100g: 654, protein100g: 15, carbs100g: 14, fat100g: 65, defaultServingG: 30,  servingUnit: "g"),
        FoodPreset(id: "cashews",      name: "Cashews",       category: .fats, calories100g: 553, protein100g: 18, carbs100g: 30, fat100g: 44, defaultServingG: 30,  servingUnit: "g"),
        FoodPreset(id: "peanut_butter", name: "Peanut Butter", category: .fats, calories100g: 588, protein100g: 25, carbs100g: 20, fat100g: 50, defaultServingG: 32,  servingUnit: "g"),
        FoodPreset(id: "olive_oil",    name: "Olive Oil",     category: .fats, calories100g: 884, protein100g: 0,  carbs100g: 0,  fat100g: 100, defaultServingG: 14, servingUnit: "ml"),
        FoodPreset(id: "flaxseed",     name: "Flaxseed",      category: .fats, calories100g: 534, protein100g: 18, carbs100g: 29, fat100g: 42, defaultServingG: 15,  servingUnit: "g"),
    ]

    // MARK: - Beverages (per 100 ml)

    private static let beverages: [FoodPreset] = [
        FoodPreset(id: "orange_juice",  name: "Orange Juice",   category: .beverages, calories100g: 45,  protein100g: 0.7, carbs100g: 10,  fat100g: 0.2, defaultServingG: 240, servingUnit: "ml"),
        FoodPreset(id: "coffee_black",  name: "Coffee (black)",  category: .beverages, calories100g: 2,   protein100g: 0.3, carbs100g: 0,   fat100g: 0,   defaultServingG: 240, servingUnit: "ml"),
        FoodPreset(id: "protein_shake", name: "Protein Shake",   category: .beverages, calories100g: 50,  protein100g: 6,   carbs100g: 4,   fat100g: 1,   defaultServingG: 300, servingUnit: "ml"),
    ]

    // MARK: - Quick meal estimates (per 100 g)

    private static let meals: [FoodPreset] = [
        FoodPreset(id: "pizza_cheese",   name: "Pizza (cheese)",    category: .meals, calories100g: 266, protein100g: 11, carbs100g: 33, fat100g: 10, defaultServingG: 100, servingUnit: "g"),
        FoodPreset(id: "burger",         name: "Burger (plain)",    category: .meals, calories100g: 295, protein100g: 17, carbs100g: 24, fat100g: 14, defaultServingG: 200, servingUnit: "g"),
        FoodPreset(id: "caesar_salad",   name: "Caesar Salad",      category: .meals, calories100g: 130, protein100g: 7,  carbs100g: 8,  fat100g: 8,  defaultServingG: 200, servingUnit: "g"),
        FoodPreset(id: "stir_fry",       name: "Chicken Stir Fry",  category: .meals, calories100g: 120, protein100g: 14, carbs100g: 8,  fat100g: 4,  defaultServingG: 300, servingUnit: "g"),
        FoodPreset(id: "sushi_roll",     name: "Sushi Roll",        category: .meals, calories100g: 150, protein100g: 6,  carbs100g: 28, fat100g: 1.5, defaultServingG: 150, servingUnit: "g"),
        FoodPreset(id: "granola_bar",    name: "Granola Bar",       category: .meals, calories100g: 471, protein100g: 8,  carbs100g: 64, fat100g: 20, defaultServingG: 40,  servingUnit: "g"),
    ]
}

// MARK: - Double rounding helper

private extension Double {
    func rounded(to places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}
