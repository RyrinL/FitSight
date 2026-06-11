import Foundation

// MARK: - Achievement evaluation engine

enum AchievementEngine {

    struct Stats {
        let streak: StreakRecord
        let sessions: [WorkoutSession]
        let nutritionDaysLogged: Int
        let waterDaysLogged: Int

        var totalKcalBurned: Int    { sessions.reduce(0) { $0 + $1.caloriesBurned } }
        var sessionCount: Int       { sessions.count }
        var bestFormScore: Int      { sessions.compactMap(\.formScore).max() ?? 0 }

        var bestSquatFormScore: Int {
            sessions
                .filter {
                    $0.title.localizedCaseInsensitiveContains("squat") ||
                    $0.exerciseType.localizedCaseInsensitiveContains("squat")
                }
                .compactMap(\.formScore).max() ?? 0
        }
    }

    // Returns a fully evaluated achievement list, preserving original earned dates
    // and newly marking ones just now satisfied.
    static func evaluate(stats: Stats, existing: [Achievement]) -> [Achievement] {
        let existingDates: [String: Date] = existing.reduce(into: [:]) {
            if let d = $1.earnedDate { $0[$1.id] = d }
        }

        var result = template(stats: stats)
        let now = Date()

        for i in result.indices {
            if let d = existingDates[result[i].id] {
                result[i].earnedDate = d          // keep first-earned timestamp
            } else if result[i].progress >= 1.0 {
                result[i].earnedDate = now         // first time crossing threshold
            }
        }
        return result
    }

    // Returns newly-earned achievement IDs compared to a previous state.
    static func newlyEarned(updated: [Achievement], previous: [Achievement]) -> [Achievement] {
        let previousEarned = Set(previous.filter { $0.isEarned }.map(\.id))
        return updated.filter { $0.isEarned && !previousEarned.contains($0.id) }
    }

    // Builds achievement definitions with live progress filled in.
    private static func template(stats: Stats) -> [Achievement] {
        let s     = stats.streak
        let count = stats.sessionCount
        let kcal  = stats.totalKcalBurned
        let form  = stats.bestFormScore
        let squat = stats.bestSquatFormScore
        let nutr  = stats.nutritionDaysLogged
        let water = stats.waterDaysLogged

        return [
            // MARK: Streak
            make("streak_3",    .streak,    "Getting Started",      "Train 3 days in a row",
                 "flame",                    .bronze, min(s.longestStreak, 3),    3),
            make("streak_7",    .streak,    "7-Day Streak",         "Train 7 days in a row",
                 "flame.fill",               .silver, min(s.longestStreak, 7),    7),
            make("streak_14",   .streak,    "Two Weeks Strong",     "Train 14 days in a row",
                 "bolt.fill",                .silver, min(s.longestStreak, 14),  14),
            make("streak_30",   .streak,    "30-Day Streak",        "Train 30 days in a row",
                 "crown.fill",               .gold,   min(s.longestStreak, 30),  30),
            make("streak_100",  .streak,    "Century",              "Train 100 days in a row",
                 "star.fill",                .gold,   min(s.longestStreak, 100), 100),

            // MARK: Workout
            make("workout_1",   .workout,   "First Rep",            "Complete your first workout",
                 "dumbbell.fill",            .bronze, min(count, 1),    1),
            make("workout_5",   .workout,   "High Five",            "Log 5 workouts",
                 "hand.raised.fill",         .bronze, min(count, 5),    5),
            make("workout_10",  .workout,   "10 Workouts",          "Log 10 workouts",
                 "10.circle.fill",           .silver, min(count, 10),  10),
            make("workout_25",  .workout,   "25 Strong",            "Log 25 workouts",
                 "25.circle.fill",           .silver, min(count, 25),  25),
            make("workout_50",  .workout,   "Half Century",         "Log 50 workouts",
                 "50.circle.fill",           .gold,   min(count, 50),  50),
            make("workout_100", .workout,   "Centurion",            "Log 100 workouts",
                 "trophy.fill",              .gold,   min(count, 100), 100),

            // MARK: Calories
            make("kcal_1000",   .calories,  "First 1,000 Burned",   "Burn 1,000 kcal through exercise",
                 "bolt.fill",                .bronze, min(kcal, 1_000),   1_000),
            make("kcal_5000",   .calories,  "5K Blaze",             "Burn 5,000 kcal through exercise",
                 "flame.fill",               .silver, min(kcal, 5_000),   5_000),
            make("kcal_10000",  .calories,  "10K Inferno",          "Burn 10,000 kcal through exercise",
                 "sun.max.fill",             .gold,   min(kcal, 10_000), 10_000),
            make("kcal_50000",  .calories,  "Calorie Crusher",      "Burn 50,000 kcal through exercise",
                 "bolt.circle.fill",         .gold,   min(kcal, 50_000), 50_000),

            // MARK: Form
            make("form_first",  .form,      "Mindful Mover",        "Complete a session with form tracking",
                 "camera.fill",              .bronze, form > 0 ? 1 : 0,  1),
            make("form_70",     .form,      "Solid Form",           "Score 70%+ on form analysis",
                 "checkmark.circle.fill",    .bronze, min(form, 70),     70),
            make("form_squat",  .form,      "Perfect Squat Form",   "Score 90%+ on squat form",
                 "figure.squat",             .silver, min(squat, 90),    90),
            make("form_95",     .form,      "Flawless",             "Score 95%+ on any form check",
                 "sparkles",                 .gold,   min(form, 95),     95),

            // MARK: Nutrition
            make("nutr_first",  .nutrition, "Fueled Up",            "Log your first meal",
                 "fork.knife",               .bronze, min(nutr, 1),    1),
            make("nutr_7",      .nutrition, "Week of Wins",         "Log meals 7 different days",
                 "calendar.badge.checkmark", .silver, min(nutr, 7),    7),
            make("nutr_30",     .nutrition, "Nutrition Champion",   "Log meals 30 different days",
                 "chart.bar.fill",           .gold,   min(nutr, 30),  30),
            make("water_7",     .nutrition, "Hydration Hero",       "Log water 7 different days",
                 "drop.fill",                .bronze, min(water, 7),   7),
        ]
    }

    private static func make(
        _ id: String, _ category: AchievementCategory,
        _ title: String, _ description: String,
        _ symbol: String, _ tier: AchievementTier,
        _ current: Int, _ target: Int
    ) -> Achievement {
        Achievement(id: id, category: category, title: title, description: description,
                    symbolName: symbol, tier: tier, earnedDate: nil,
                    currentValue: current, targetValue: target)
    }
}
