import Foundation

enum RecommendationEngine {

    // MARK: - Today's recommendations

    static func recommendations(
        profile: UserProfile,
        recoveryStatus: RecoveryStatus,
        remainingCalories: Double
    ) -> [WorkoutRecommendation] {
        let equipment = profile.availableEquipment.isEmpty ? [Equipment.bodyweight] : profile.availableEquipment
        let minutes = max(profile.workoutMinutes, 10)

        // Near or past calorie goal → light session only
        if remainingCalories <= 40 {
            return [recoveryOption(equipment: equipment, minutes: min(minutes, 20))]
        }

        // Tired or sore → active recovery
        if recoveryStatus == .sore || recoveryStatus == .tired {
            return [recoveryOption(equipment: equipment, minutes: min(minutes, 20))]
        }

        let sessionType = primarySessionType(focus: profile.workoutFocus, goal: profile.fitnessGoal)
        let exercises = buildExercises(
            sessionType: sessionType,
            goal: profile.fitnessGoal,
            experience: profile.experienceLevel,
            equipment: equipment,
            recoveryStatus: recoveryStatus,
            targetMinutes: minutes
        )
        let calories = Int(Double(minutes) * calorieRate(for: sessionType, experience: profile.experienceLevel) * recoveryStatus.intensityMultiplier)

        let primary = WorkoutRecommendation(
            title: sessionType.rawValue,
            subtitle: subtitle(goal: profile.fitnessGoal, recovery: recoveryStatus),
            minutes: minutes,
            calories: calories,
            intensity: intensityLabel(goal: profile.fitnessGoal, recovery: recoveryStatus),
            symbolName: sessionType.symbolName,
            exercises: exercises
        )

        return [primary, recoveryOption(equipment: [.bodyweight], minutes: min(minutes / 2, 20))]
    }

    // MARK: - Weekly plan

    static func weeklyPlan(for profile: UserProfile) -> WorkoutPlan {
        let equipment = profile.availableEquipment.isEmpty ? [Equipment.bodyweight] : profile.availableEquipment
        let daysPerWeek = trainingDays(for: profile.activityLevel)
        let split = buildSplit(daysPerWeek: daysPerWeek, experience: profile.experienceLevel, focus: profile.workoutFocus)
        let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

        let days: [WorkoutDay] = weekdays.enumerated().map { i, name in
            let sessionType = i < split.count ? split[i] : .rest
            guard sessionType != .rest else {
                return WorkoutDay(
                    id: UUID().uuidString,
                    weekdayIndex: i + 1, weekdayName: name,
                    sessionType: .rest, exercises: [],
                    estimatedMinutes: 0, estimatedCalories: 0,
                    notes: "Rest — let your body recover."
                )
            }
            let exercises = buildExercises(
                sessionType: sessionType,
                goal: profile.fitnessGoal,
                experience: profile.experienceLevel,
                equipment: equipment,
                recoveryStatus: .normal,
                targetMinutes: profile.workoutMinutes
            )
            let estCal = Int(Double(profile.workoutMinutes) * calorieRate(for: sessionType, experience: profile.experienceLevel))
            return WorkoutDay(
                id: UUID().uuidString,
                weekdayIndex: i + 1, weekdayName: name,
                sessionType: sessionType, exercises: exercises,
                estimatedMinutes: profile.workoutMinutes,
                estimatedCalories: estCal, notes: ""
            )
        }

        let trainingDayTypes = split.filter { $0 != .rest }
        return WorkoutPlan(
            id: UUID().uuidString,
            userId: profile.id,
            createdAt: Date(),
            goal: profile.fitnessGoal,
            experience: profile.experienceLevel,
            equipment: equipment,
            days: days,
            splitName: splitName(for: trainingDayTypes),
            weeklyVolume: days.reduce(0) { $0 + $1.exercises.reduce(0) { $0 + $1.sets } },
            notes: "Generated for \(profile.fitnessGoal.rawValue.lowercased()) goal, \(profile.experienceLevel.rawValue.lowercased()) level."
        )
    }

    // MARK: - Private: exercises

    private static func buildExercises(
        sessionType: SessionType,
        goal: FitnessGoal,
        experience: ExperienceLevel,
        equipment: [Equipment],
        recoveryStatus: RecoveryStatus,
        targetMinutes: Int
    ) -> [ExerciseBlock] {
        let templates = ExerciseLibrary.exercises(for: sessionType, equipment: equipment, experience: experience).shuffled()
        let count = exerciseCount(minutes: targetMinutes, sessionType: sessionType)
        return templates.prefix(count).map { t in
            let (sets, lo, hi, rest) = scheme(goal: goal, experience: experience, recovery: recoveryStatus, sessionType: sessionType)
            return t.block(sets: sets, repsLow: lo, repsHigh: hi, restSeconds: rest)
        }
    }

    private static func exerciseCount(minutes: Int, sessionType: SessionType) -> Int {
        switch sessionType {
        case .activeRecovery: return min(minutes / 3, 6)
        case .hiit, .cardio:  return min(minutes / 4, 5)
        default:              return min(minutes / 5, 6)
        }
    }

    private static func scheme(
        goal: FitnessGoal,
        experience: ExperienceLevel,
        recovery: RecoveryStatus,
        sessionType: SessionType
    ) -> (sets: Int, repsLow: Int, repsHigh: Int, rest: Int) {
        if sessionType == .activeRecovery { return (1, 30, 45, 20) }
        if sessionType == .cardio || sessionType == .hiit { return (3, 20, 30, 30) }

        let baseSets: Int
        switch experience {
        case .beginner:     baseSets = 2
        case .intermediate: baseSets = 3
        case .advanced:     baseSets = 4
        }

        let (lo, hi, rest): (Int, Int, Int)
        switch goal {
        case .fatLoss:     (lo, hi, rest) = (12, 15, 45)
        case .maintenance: (lo, hi, rest) = (10, 12, 60)
        case .strength:    (lo, hi, rest) = (4,  6,  120)
        case .endurance:   (lo, hi, rest) = (15, 20, 30)
        }

        let adjustedSets = max(1, Int(Double(baseSets) * recovery.intensityMultiplier))
        return (adjustedSets, lo, hi, rest)
    }

    private static func calorieRate(for sessionType: SessionType, experience: ExperienceLevel) -> Double {
        let base: Double
        switch sessionType {
        case .hiit:                      base = 12
        case .cardio:                    base = 10
        case .fullBody:                  base = 9
        case .legs, .lower:              base = 8
        case .push, .pull, .upper:       base = 7
        case .activeRecovery:            base = 4
        case .rest:                      base = 0
        }
        return experience == .advanced ? base * 1.1 : base
    }

    // MARK: - Private: plan structure

    private static func trainingDays(for level: ActivityLevel) -> Int {
        switch level {
        case .sedentary:        return 2
        case .lightlyActive:    return 3
        case .moderatelyActive: return 4
        case .veryActive:       return 5
        case .extraActive:      return 6
        }
    }

    private static func buildSplit(daysPerWeek: Int, experience: ExperienceLevel, focus: WorkoutFocus) -> [SessionType] {
        switch daysPerWeek {
        case 2:
            return [.fullBody, .rest, .rest, .fullBody, .rest, .rest, .rest]
        case 3:
            if focus == .cardio {
                return [.cardio, .rest, .hiit, .rest, .cardio, .rest, .rest]
            }
            if experience == .beginner {
                return [.fullBody, .rest, .fullBody, .rest, .fullBody, .rest, .rest]
            }
            return [.push, .rest, .pull, .rest, .legs, .rest, .rest]
        case 4:
            switch focus {
            case .cardio:
                return [.cardio, .rest, .hiit, .rest, .cardio, .rest, .hiit]
            case .strength, .balanced:
                return [.upper, .lower, .rest, .upper, .lower, .rest, .rest]
            default:
                return [.push, .pull, .rest, .legs, .fullBody, .rest, .rest]
            }
        case 5:
            return [.push, .pull, .legs, .rest, .upper, .lower, .rest]
        default: // 6
            return [.push, .pull, .legs, .rest, .push, .pull, .legs]
        }
    }

    private static func splitName(for types: [SessionType]) -> String {
        switch types.count {
        case 2: return "2-Day Full Body"
        case 3 where types.contains(.push): return "Push / Pull / Legs"
        case 3 where types.allSatisfy({ $0 == .fullBody }): return "3-Day Full Body"
        case 3: return "3-Day Split"
        case 4 where types.contains(.upper): return "Upper / Lower Split"
        case 5: return "5-Day PPL + Upper/Lower"
        case 6: return "6-Day PPL Double"
        default: return "Custom Split"
        }
    }

    // MARK: - Private: labels

    private static func primarySessionType(focus: WorkoutFocus, goal: FitnessGoal) -> SessionType {
        switch focus {
        case .strength:  return .fullBody
        case .cardio:    return goal == .endurance ? .cardio : .hiit
        case .lowImpact: return .activeRecovery
        case .mobility:  return .activeRecovery
        case .balanced:  return goal == .strength ? .upper : .fullBody
        }
    }

    private static func intensityLabel(goal: FitnessGoal, recovery: RecoveryStatus) -> String {
        if recovery == .sore || recovery == .tired { return "Easy" }
        switch goal {
        case .fatLoss:     return "Moderate"
        case .maintenance: return "Moderate"
        case .strength:    return "Heavy"
        case .endurance:   return "Steady"
        }
    }

    private static func subtitle(goal: FitnessGoal, recovery: RecoveryStatus) -> String {
        if recovery == .tired { return "Scaled back today — quality reps over volume." }
        if recovery == .sore  { return "Mobility focus to flush soreness and stay on track." }
        switch goal {
        case .fatLoss:     return "High rep density to maximise calorie burn."
        case .maintenance: return "Balanced effort to sustain fitness and energy."
        case .strength:    return "Lower reps, heavier loads, longer rest."
        case .endurance:   return "High reps with minimal rest to build work capacity."
        }
    }

    private static func recoveryOption(equipment: [Equipment], minutes: Int) -> WorkoutRecommendation {
        let templates = ExerciseLibrary.exercises(for: .activeRecovery, equipment: [.bodyweight], experience: .beginner)
        let exercises = templates.prefix(5).map { t in t.block(sets: 1, repsLow: 30, repsHigh: 45, restSeconds: 20) }
        return WorkoutRecommendation(
            title: "Active Recovery",
            subtitle: "Light mobility to flush soreness and keep your streak alive.",
            minutes: minutes, calories: 80,
            intensity: "Easy", symbolName: SessionType.activeRecovery.symbolName,
            exercises: Array(exercises)
        )
    }
}
