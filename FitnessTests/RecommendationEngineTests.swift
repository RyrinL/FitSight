import XCTest
@testable import Fitness

final class RecommendationEngineTests: XCTestCase {

    // MARK: - Helpers

    private func makeProfile(
        activity: ActivityLevel = .moderatelyActive,
        goal: FitnessGoal = .fatLoss,
        focus: WorkoutFocus = .balanced,
        experience: ExperienceLevel = .beginner,
        minutes: Int = 30
    ) -> UserProfile {
        UserProfile(
            id: "test", email: "t@t.com", displayName: "Test",
            age: 28, weightKg: 75, heightCm: 175,
            sex: .male, activityLevel: activity,
            fitnessGoal: goal, workoutFocus: focus,
            workoutMinutes: minutes, joinedDate: Date(),
            experienceLevel: experience, availableEquipment: [.bodyweight]
        )
    }

    // MARK: - Today's recommendations

    func test_recommendations_normal_returnsNonEmpty() {
        let profile = makeProfile()
        let recs = RecommendationEngine.recommendations(
            profile: profile, recoveryStatus: .normal, remainingCalories: 400
        )
        XCTAssertFalse(recs.isEmpty)
    }

    func test_recommendations_alwaysHaveValidFields() {
        let profile = makeProfile()
        let recs = RecommendationEngine.recommendations(
            profile: profile, recoveryStatus: .normal, remainingCalories: 300
        )
        for rec in recs {
            XCTAssertFalse(rec.title.isEmpty)
            XCTAssertGreaterThan(rec.minutes, 0)
            XCTAssertGreaterThanOrEqual(rec.calories, 0)
        }
    }

    func test_recommendations_lowRemainingCalories_returnsActiveRecovery() {
        // ≤ 40 kcal remaining → always active recovery
        let profile = makeProfile(goal: .fatLoss)
        let recs = RecommendationEngine.recommendations(
            profile: profile, recoveryStatus: .normal, remainingCalories: 20
        )
        XCTAssertEqual(recs.count, 1)
        XCTAssertTrue(recs.first?.title.localizedCaseInsensitiveContains("Recovery") == true)
    }

    func test_recommendations_soreStatus_returnsActiveRecovery() {
        let profile = makeProfile()
        let recs = RecommendationEngine.recommendations(
            profile: profile, recoveryStatus: .sore, remainingCalories: 500
        )
        XCTAssertEqual(recs.count, 1)
        XCTAssertTrue(recs.first?.title.localizedCaseInsensitiveContains("Recovery") == true)
    }

    func test_recommendations_tiredStatus_returnsActiveRecovery() {
        let profile = makeProfile()
        let recs = RecommendationEngine.recommendations(
            profile: profile, recoveryStatus: .tired, remainingCalories: 500
        )
        XCTAssertEqual(recs.count, 1)
        XCTAssertTrue(recs.first?.title.localizedCaseInsensitiveContains("Recovery") == true)
    }

    func test_recommendations_normalStatus_returnsTwoOptions() {
        // Normal with enough calories → primary + recovery option
        let profile = makeProfile()
        let recs = RecommendationEngine.recommendations(
            profile: profile, recoveryStatus: .normal, remainingCalories: 400
        )
        XCTAssertEqual(recs.count, 2)
    }

    func test_recommendations_exercises_arePopulated() {
        let profile = makeProfile()
        let recs = RecommendationEngine.recommendations(
            profile: profile, recoveryStatus: .normal, remainingCalories: 300
        )
        let primary = recs.first!
        XCTAssertFalse(primary.exercises.isEmpty)
        XCTAssertFalse(primary.steps.isEmpty)
    }

    func test_recommendations_allGoals_returnValidResults() {
        for goal in FitnessGoal.allCases {
            let profile = makeProfile(goal: goal)
            let recs = RecommendationEngine.recommendations(
                profile: profile, recoveryStatus: .normal, remainingCalories: 300
            )
            XCTAssertFalse(recs.isEmpty, "No recs for goal \(goal.rawValue)")
        }
    }

    func test_recommendations_allFocuses_returnValidResults() {
        for focus in WorkoutFocus.allCases {
            let profile = makeProfile(focus: focus)
            let recs = RecommendationEngine.recommendations(
                profile: profile, recoveryStatus: .normal, remainingCalories: 300
            )
            XCTAssertFalse(recs.isEmpty, "No recs for focus \(focus.rawValue)")
        }
    }

    func test_recommendations_cardioFocus_returnsCardioOrHIIT() {
        let profile = makeProfile(goal: .fatLoss, focus: .cardio)
        let recs = RecommendationEngine.recommendations(
            profile: profile, recoveryStatus: .normal, remainingCalories: 400
        )
        let primary = recs.first!
        let isCardioOrHIIT = primary.title.localizedCaseInsensitiveContains("HIIT")
            || primary.title.localizedCaseInsensitiveContains("Cardio")
        XCTAssertTrue(isCardioOrHIIT, "Cardio focus should return HIIT or Cardio session, got: \(primary.title)")
    }

    func test_recommendations_advancedExperience_returnsMoreCalories() {
        let beginner = makeProfile(experience: .beginner)
        let advanced = makeProfile(experience: .advanced)
        let recsB = RecommendationEngine.recommendations(
            profile: beginner, recoveryStatus: .normal, remainingCalories: 400
        )
        let recsA = RecommendationEngine.recommendations(
            profile: advanced, recoveryStatus: .normal, remainingCalories: 400
        )
        XCTAssertGreaterThanOrEqual(recsA.first!.calories, recsB.first!.calories)
    }

    func test_recommendations_minutes_matchProfile() {
        let profile = makeProfile(minutes: 45)
        let recs = RecommendationEngine.recommendations(
            profile: profile, recoveryStatus: .normal, remainingCalories: 400
        )
        XCTAssertEqual(recs.first!.minutes, 45)
    }

    // MARK: - Weekly plan

    func test_weeklyPlan_hasSevenDays() {
        let profile = makeProfile()
        let plan = RecommendationEngine.weeklyPlan(for: profile)
        XCTAssertEqual(plan.days.count, 7)
    }

    func test_weeklyPlan_sedentary_hasTwoTrainingDays() {
        let profile = makeProfile(activity: .sedentary)
        let plan = RecommendationEngine.weeklyPlan(for: profile)
        let trainingDays = plan.days.filter { $0.sessionType != .rest }
        XCTAssertEqual(trainingDays.count, 2)
    }

    func test_weeklyPlan_veryActive_hasFiveTrainingDays() {
        let profile = makeProfile(activity: .veryActive)
        let plan = RecommendationEngine.weeklyPlan(for: profile)
        let trainingDays = plan.days.filter { $0.sessionType != .rest }
        XCTAssertEqual(trainingDays.count, 5)
    }

    func test_weeklyPlan_weekdayNames_areCorrect() {
        let profile = makeProfile()
        let plan = RecommendationEngine.weeklyPlan(for: profile)
        let expected = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        XCTAssertEqual(plan.days.map(\.weekdayName), expected)
    }

    func test_weeklyPlan_trainingDays_haveExercises() {
        let profile = makeProfile()
        let plan = RecommendationEngine.weeklyPlan(for: profile)
        for day in plan.days where day.sessionType != .rest {
            XCTAssertFalse(day.exercises.isEmpty, "Training day \(day.weekdayName) has no exercises")
            XCTAssertGreaterThan(day.estimatedMinutes, 0)
            XCTAssertGreaterThan(day.estimatedCalories, 0)
        }
    }

    func test_weeklyPlan_restDays_haveNoExercises() {
        let profile = makeProfile(activity: .sedentary)
        let plan = RecommendationEngine.weeklyPlan(for: profile)
        for day in plan.days where day.sessionType == .rest {
            XCTAssertTrue(day.exercises.isEmpty)
            XCTAssertEqual(day.estimatedMinutes, 0)
        }
    }

    func test_weeklyPlan_matchesProfileGoalAndExperience() {
        let profile = makeProfile(goal: .strength, experience: .advanced)
        let plan = RecommendationEngine.weeklyPlan(for: profile)
        XCTAssertEqual(plan.goal, .strength)
        XCTAssertEqual(plan.experience, .advanced)
    }
}
