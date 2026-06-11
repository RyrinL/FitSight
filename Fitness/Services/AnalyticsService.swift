// MARK: - AnalyticsService
// Active when FirebaseAnalytics is linked via SPM.
// SPM: https://github.com/firebase/firebase-ios-sdk  target: FirebaseAnalytics
//
// Analytics starts automatically once FirebaseApp.configure() is called.
// All calls below are no-ops when the SDK is not linked.

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

enum AnalyticsService {

    // MARK: - Identity

    static func setUser(uid: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.setUserID(uid)
        #endif
    }

    // MARK: - Workout events

    static func logWorkout(type: String, minutes: Int, calories: Int) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent("workout_logged", parameters: [
            "exercise_type":     type      as NSObject,
            "duration_minutes":  minutes   as NSObject,
            "calories_burned":   calories  as NSObject,
        ])
        #endif
    }

    // MARK: - Nutrition events

    static func logMeal(mealType: String, calories: Double) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent("meal_logged", parameters: [
            "meal_type": mealType         as NSObject,
            "calories":  Int(calories)    as NSObject,
        ])
        #endif
    }

    static func logWater(amountMl: Double) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent("water_logged", parameters: [
            "amount_ml": Int(amountMl) as NSObject,
        ])
        #endif
    }

    // MARK: - Achievement events

    static func logAchievementEarned(id: String, tier: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(AnalyticsEventUnlockAchievement, parameters: [
            AnalyticsParameterAchievementID: id   as NSObject,
            "tier":                          tier as NSObject,
        ])
        #endif
    }

    // MARK: - Streak events

    static func logStreakMilestone(days: Int) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent("streak_milestone", parameters: [
            "streak_days": days as NSObject,
        ])
        #endif
    }

    // MARK: - Goal events

    static func logGoalUpdated(goal: String, calorieTarget: Int) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent("goal_updated", parameters: [
            "fitness_goal":   goal          as NSObject,
            "calorie_target": calorieTarget as NSObject,
        ])
        #endif
    }
}
