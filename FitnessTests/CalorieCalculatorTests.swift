import XCTest
@testable import Fitness

final class CalorieCalculatorTests: XCTestCase {

    // MARK: - Helpers

    private func makeProfile(
        sex: BiologicalSex = .male,
        age: Int = 30,
        weightKg: Double = 75,
        heightCm: Double = 175,
        activity: ActivityLevel = .moderatelyActive,
        goal: FitnessGoal = .fatLoss
    ) -> UserProfile {
        UserProfile(
            id: "test", email: "t@t.com", displayName: "Test",
            age: age, weightKg: weightKg, heightCm: heightCm,
            sex: sex, activityLevel: activity,
            fitnessGoal: goal, workoutFocus: .balanced,
            workoutMinutes: 30, joinedDate: Date()
        )
    }

    // MARK: - BMR

    func test_maleBMR_isPositive() {
        XCTAssertGreaterThan(makeProfile(sex: .male).bmr, 0)
    }

    func test_femaleBMR_isLessThanMaleBMR() {
        let male   = makeProfile(sex: .male)
        let female = makeProfile(sex: .female)
        XCTAssertGreaterThan(male.bmr, female.bmr)
    }

    func test_otherBMR_isBetweenMaleAndFemale() {
        let male   = makeProfile(sex: .male)
        let female = makeProfile(sex: .female)
        let other  = makeProfile(sex: .other)
        XCTAssertGreaterThan(other.bmr, female.bmr)
        XCTAssertGreaterThan(male.bmr, other.bmr)
    }

    func test_mifflinStJeor_knownMaleValue() {
        // Male, 25yo, 80kg, 180cm:
        // base = (10×80) + (6.25×180) − (5×25) = 800 + 1125 − 125 = 1800
        // male  = base + 5 = 1805
        let p = UserProfile(
            id: "t", email: "", displayName: "",
            age: 25, weightKg: 80, heightCm: 180,
            sex: .male, activityLevel: .sedentary,
            fitnessGoal: .maintenance, workoutFocus: .balanced,
            workoutMinutes: 30, joinedDate: Date()
        )
        XCTAssertEqual(p.bmr, 1805, accuracy: 1)
    }

    func test_mifflinStJeor_knownFemaleValue() {
        // Female, 25yo, 80kg, 180cm:
        // base = 1800, female = 1800 − 161 = 1639
        let p = UserProfile(
            id: "t", email: "", displayName: "",
            age: 25, weightKg: 80, heightCm: 180,
            sex: .female, activityLevel: .sedentary,
            fitnessGoal: .maintenance, workoutFocus: .balanced,
            workoutMinutes: 30, joinedDate: Date()
        )
        XCTAssertEqual(p.bmr, 1639, accuracy: 1)
    }

    // MARK: - TDEE

    func test_tdee_isGreaterThanBMR() {
        let p = makeProfile()
        XCTAssertGreaterThan(p.tdee, p.bmr)
    }

    func test_tdee_sedentary_multiplier() {
        // Sedentary multiplier = 1.2
        let p = makeProfile(activity: .sedentary, goal: .maintenance)
        XCTAssertEqual(p.tdee, p.bmr * 1.2, accuracy: 0.5)
    }

    func test_tdee_extraActive_isHighest() {
        let sedentary    = makeProfile(activity: .sedentary)
        let extraActive  = makeProfile(activity: .extraActive)
        XCTAssertGreaterThan(extraActive.tdee, sedentary.tdee)
    }

    // MARK: - Recommended calories

    func test_recommendedCalories_fatLoss_isLessThanTDEE() {
        let p = makeProfile(goal: .fatLoss)
        XCTAssertLessThan(p.recommendedDailyCalories, p.tdee)
    }

    func test_recommendedCalories_strength_isGreaterThanTDEE() {
        let p = makeProfile(goal: .strength)
        XCTAssertGreaterThan(p.recommendedDailyCalories, p.tdee)
    }

    func test_recommendedCalories_maintenance_equalsTDEE() {
        let p = makeProfile(goal: .maintenance)
        XCTAssertEqual(p.recommendedDailyCalories, p.tdee, accuracy: 0.5)
    }

    func test_recommendedCalories_maleFloor_isAtLeast1500() {
        // Tiny sedentary male: floor should be 1500
        let p = makeProfile(sex: .male, age: 20, weightKg: 40, heightCm: 150,
                            activity: .sedentary, goal: .fatLoss)
        XCTAssertGreaterThanOrEqual(p.recommendedDailyCalories, 1500)
    }

    func test_recommendedCalories_femaleFloor_isAtLeast1200() {
        // Very small sedentary female on fat-loss deficit → should hit 1200 floor
        let p = makeProfile(sex: .female, age: 20, weightKg: 45, heightCm: 155,
                            activity: .sedentary, goal: .fatLoss)
        XCTAssertGreaterThanOrEqual(p.recommendedDailyCalories, 1200)
    }

    // MARK: - Active calorie goal

    func test_activeCalorieGoal_fatLoss_isAtLeast400() {
        let p = makeProfile(activity: .sedentary, goal: .fatLoss)
        XCTAssertGreaterThanOrEqual(p.computedActiveCalorieGoal, 400)
    }

    func test_activeCalorieGoal_endurance_isHigherThanStrength() {
        let endurance = makeProfile(activity: .veryActive, goal: .endurance)
        let strength  = makeProfile(activity: .veryActive, goal: .strength)
        XCTAssertGreaterThan(endurance.computedActiveCalorieGoal, strength.computedActiveCalorieGoal)
    }

    func test_activeCalorieGoal_allGoals_aboveFloor() {
        for goal in FitnessGoal.allCases {
            let p = makeProfile(activity: .sedentary, goal: goal)
            XCTAssertGreaterThanOrEqual(p.computedActiveCalorieGoal, goal.activeCalorieFloor,
                                        "Goal \(goal.rawValue) is below its own floor")
        }
    }

    // MARK: - MacroTargets

    func test_macros_fatLoss_highProtein() {
        let targets = MacroTargets.compute(calories: 2000, goal: .fatLoss)
        // Fat loss: 40% protein → 200g
        XCTAssertEqual(targets.proteinG, 200, accuracy: 1)
        XCTAssertEqual(targets.calories, 2000, accuracy: 0.1)
    }

    func test_macros_endurance_highCarbs() {
        let targets = MacroTargets.compute(calories: 2000, goal: .endurance)
        // Endurance: 25% protein, 50% carbs, 25% fat
        XCTAssertEqual(targets.carbsG, 250, accuracy: 1)   // 2000*0.50/4
        XCTAssertEqual(targets.proteinG, 125, accuracy: 1) // 2000*0.25/4
    }

    func test_macros_fractions_sumToOne() {
        for goal in FitnessGoal.allCases {
            let m = MacroTargets.compute(calories: 2000, goal: goal)
            let sum = m.proteinFraction + m.carbsFraction + m.fatFraction
            XCTAssertEqual(sum, 1.0, accuracy: 0.02, "Fractions don't sum to 1 for \(goal.rawValue)")
        }
    }

    func test_macros_kcal_matchesCalories() {
        let m = MacroTargets.compute(calories: 2000, goal: .strength)
        XCTAssertEqual(m.proteinKcal + m.carbsKcal + m.fatKcal, 2000, accuracy: 2)
    }

    // MARK: - StreakRecord

    func test_streakMarkActiveToday_incrementsStreak() {
        var streak = StreakRecord.empty(userId: "u1")
        streak.markActiveToday()
        XCTAssertEqual(streak.currentStreak, 1)
        XCTAssertEqual(streak.longestStreak, 1)
        XCTAssertEqual(streak.totalActiveDays, 1)
        XCTAssertTrue(streak.isActiveToday)
    }

    func test_streakMarkActiveToday_idempotent() {
        var streak = StreakRecord.empty(userId: "u1")
        streak.markActiveToday()
        streak.markActiveToday()  // second call same day → no change
        XCTAssertEqual(streak.currentStreak, 1)
        XCTAssertEqual(streak.totalActiveDays, 1)
    }

    func test_streakBreak_resetsToOne_preservesLongest() {
        var streak = StreakRecord(
            userId: "u1", currentStreak: 5, longestStreak: 5,
            lastActiveDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()),
            totalActiveDays: 5
        )
        streak.markActiveToday()
        XCTAssertEqual(streak.currentStreak, 1)
        XCTAssertEqual(streak.longestStreak, 5)
    }

    func test_streakConsecutiveDays_increments() {
        var streak = StreakRecord(
            userId: "u1", currentStreak: 3, longestStreak: 3,
            lastActiveDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
            totalActiveDays: 3
        )
        streak.markActiveToday()
        XCTAssertEqual(streak.currentStreak, 4)
        XCTAssertEqual(streak.longestStreak, 4)
        XCTAssertEqual(streak.totalActiveDays, 4)
    }

    // MARK: - AchievementEngine

    func test_achievementEngine_sevenDayStreak_isEarned() {
        let streak = StreakRecord(userId: "u", currentStreak: 7, longestStreak: 7,
                                  lastActiveDate: Date(), totalActiveDays: 7)
        let stats = AchievementEngine.Stats(streak: streak, sessions: [],
                                            nutritionDaysLogged: 0, waterDaysLogged: 0)
        let achievements = AchievementEngine.evaluate(stats: stats, existing: [])
        let sevenDay = achievements.first { $0.id == "streak_7" }
        XCTAssertNotNil(sevenDay)
        XCTAssertTrue(sevenDay!.isEarned)
        XCTAssertEqual(sevenDay!.progress, 1.0, accuracy: 0.01)
    }

    func test_achievementEngine_tenWorkouts_isEarned() {
        let sessions = (0..<10).map { i in
            WorkoutSession(id: "\(i)", userId: "u", title: "Workout",
                           date: Date(), durationMinutes: 30,
                           caloriesBurned: 200, exerciseType: "Full Body",
                           notes: "", formScore: nil)
        }
        let streak = StreakRecord.empty(userId: "u")
        let stats = AchievementEngine.Stats(streak: streak, sessions: sessions,
                                            nutritionDaysLogged: 0, waterDaysLogged: 0)
        let achievements = AchievementEngine.evaluate(stats: stats, existing: [])
        let ten = achievements.first { $0.id == "workout_10" }
        XCTAssertTrue(ten!.isEarned)
        let twentyFive = achievements.first { $0.id == "workout_25" }
        XCTAssertFalse(twentyFive!.isEarned)
    }

    func test_achievementEngine_preservesEarnedDate() {
        let streak = StreakRecord(userId: "u", currentStreak: 7, longestStreak: 7,
                                  lastActiveDate: Date(), totalActiveDays: 7)
        let stats = AchievementEngine.Stats(streak: streak, sessions: [],
                                            nutritionDaysLogged: 0, waterDaysLogged: 0)
        let firstEval  = AchievementEngine.evaluate(stats: stats, existing: [])
        let sevenDay   = firstEval.first { $0.id == "streak_7" }!
        let earnedDate = sevenDay.earnedDate!

        // Second evaluation should preserve original earned date.
        let secondEval = AchievementEngine.evaluate(stats: stats, existing: firstEval)
        let sevenDay2  = secondEval.first { $0.id == "streak_7" }!
        XCTAssertEqual(sevenDay2.earnedDate, earnedDate)
    }

    func test_achievementEngine_newlyEarned_detectsFirstCross() {
        let streak = StreakRecord(userId: "u", currentStreak: 3, longestStreak: 3,
                                  lastActiveDate: Date(), totalActiveDays: 3)
        let stats0 = AchievementEngine.Stats(streak: streak, sessions: [],
                                             nutritionDaysLogged: 0, waterDaysLogged: 0)
        let before = AchievementEngine.evaluate(stats: stats0, existing: [])

        let streak7 = StreakRecord(userId: "u", currentStreak: 7, longestStreak: 7,
                                   lastActiveDate: Date(), totalActiveDays: 7)
        let stats7 = AchievementEngine.Stats(streak: streak7, sessions: [],
                                             nutritionDaysLogged: 0, waterDaysLogged: 0)
        let after  = AchievementEngine.evaluate(stats: stats7, existing: before)
        let newly  = AchievementEngine.newlyEarned(updated: after, previous: before)
        XCTAssertTrue(newly.contains { $0.id == "streak_7" })
    }

    // MARK: - NutritionEntry

    func test_nutritionEntry_macroTotals() {
        let entry = NutritionEntry.new(userId: "u1", foodName: "Chicken", calories: 300,
                                       protein: 40, carbs: 10, fat: 8, meal: .lunch)
        XCTAssertEqual(entry.calories, 300)
        XCTAssertEqual(entry.proteinG, 40)
        XCTAssertEqual(entry.carbsG, 10)
        XCTAssertEqual(entry.fatG, 8)
        XCTAssertEqual(entry.mealType, .lunch)
    }
}
