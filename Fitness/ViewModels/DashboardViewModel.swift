import Foundation
import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var activeEnergy: Double = 0
    @Published var weeklyMetrics: [DailyMetric] = []
    @Published var workoutHistory: [WorkoutSession] = []
    @Published var isLoading = false
    @Published var recoveryStatus: RecoveryStatus = .normal
    @Published var weeklyPlan: WorkoutPlan?
    @Published var customPlan: WorkoutPlan?

    private let db: any DatabaseServiceProtocol
    private let healthKit: HealthKitService

    var profile: UserProfile?
    var streak: StreakRecord = .empty(userId: "")

    init(db: any DatabaseServiceProtocol, healthKit: HealthKitService) {
        self.db = db
        self.healthKit = healthKit
    }

    // MARK: - Calorie calculations (all derived from profile via UserProfile computed props)

    /// Basal metabolic rate (Mifflin-St Jeor)
    var bmr: Double { profile?.bmr ?? 0 }

    /// Total daily energy expenditure = BMR × activity multiplier
    var tdee: Double { profile?.tdee ?? 0 }

    /// Dietary calorie target (TDEE ± goal adjustment, floored at sex-specific minimum)
    var recommendedDailyCalories: Double { profile?.recommendedDailyCalories ?? tdee }

    /// Exercise-ring target — fraction of TDEE to burn through intentional exercise
    var dailyCalorieGoal: Double { profile?.computedActiveCalorieGoal ?? 650 }

    var activeEnergyProgress: Double {
        guard dailyCalorieGoal > 0 else { return 0 }
        return min(activeEnergy / dailyCalorieGoal, 1.0)
    }

    var remainingCalories: Double { max(dailyCalorieGoal - activeEnergy, 0) }

    var macroTargets: MacroTargets? { profile?.macroTargets }

    // MARK: - Recommendations

    var recommendations: [WorkoutRecommendation] {
        guard let profile else { return [] }
        return RecommendationEngine.recommendations(
            profile: profile,
            recoveryStatus: recoveryStatus,
            remainingCalories: remainingCalories
        )
    }

    // MARK: - Data loading

    func loadData(uid: String) async {
        isLoading = true
        defer { isLoading = false }
        activeEnergy = healthKit.activeEnergyToday
        workoutHistory = (try? await db.fetchWorkoutHistory(uid: uid, limit: 50)) ?? []
        weeklyMetrics = await healthKit.weeklyActiveEnergy()
        weeklyPlan = try? await db.fetchLatestWorkoutPlan(uid: uid)
    }

    func logWorkout(_ rec: WorkoutRecommendation, uid: String) async {
        let session = WorkoutSession.new(
            userId: uid, title: rec.title,
            minutes: rec.minutes, calories: rec.calories,
            type: rec.symbolName
        )
        try? await db.saveWorkoutSession(session)
        workoutHistory.insert(session, at: 0)
    }

    /// Log a single day from a weekly/custom plan into the daily workout history.
    func logWorkout(_ day: WorkoutDay, uid: String) async {
        let session = WorkoutSession.new(
            userId: uid,
            title: "\(day.sessionType.rawValue) · \(day.weekdayName)",
            minutes: day.estimatedMinutes,
            calories: day.estimatedCalories,
            type: day.sessionType.symbolName
        )
        try? await db.saveWorkoutSession(session)
        workoutHistory.insert(session, at: 0)
    }

    func onHealthKitRefresh() {
        activeEnergy = healthKit.activeEnergyToday
    }

    func saveCustomPlan(_ plan: WorkoutPlan, uid: String) async {
        customPlan = plan
        try? await db.saveWorkoutPlan(plan)
    }

    func generateAndSavePlan(uid: String) async {
        guard let profile else { return }
        let plan = await AICoachService.shared.generateWeeklyPlan(profile: profile, recovery: recoveryStatus)
        weeklyPlan = plan
        try? await db.saveWorkoutPlan(plan)
    }

    func loadPlan(uid: String) async {
        weeklyPlan = try? await db.fetchLatestWorkoutPlan(uid: uid)
    }
}
