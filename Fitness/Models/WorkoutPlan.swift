import Foundation

// MARK: - Experience & Equipment

enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
    case beginner     = "Beginner"
    case intermediate = "Intermediate"
    case advanced     = "Advanced"
    var id: String { rawValue }

    var description: String {
        switch self {
        case .beginner:     return "Less than 1 year of consistent training"
        case .intermediate: return "1–3 years of consistent training"
        case .advanced:     return "3+ years of consistent training"
        }
    }
}

enum Equipment: String, Codable, CaseIterable, Identifiable {
    case bodyweight      = "Bodyweight"
    case dumbbells       = "Dumbbells"
    case barbell         = "Barbell"
    case kettlebell      = "Kettlebell"
    case resistanceBands = "Resistance Bands"
    case pullupBar       = "Pull-up Bar"
    case cables          = "Cables"
    case cardioMachine   = "Cardio Machine"
    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .bodyweight:      return "figure.stand"
        case .dumbbells:       return "dumbbell.fill"
        case .barbell:         return "dumbbell"
        case .kettlebell:      return "figure.strengthtraining.traditional"
        case .resistanceBands: return "arrow.left.arrow.right"
        case .pullupBar:       return "chevron.up.2"
        case .cables:          return "link.circle"
        case .cardioMachine:   return "figure.run.circle"
        }
    }
}

enum RecoveryStatus: String, Codable, CaseIterable, Identifiable {
    case fresh  = "Fresh"
    case normal = "Normal"
    case tired  = "Tired"
    case sore   = "Sore"
    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .fresh:  return "bolt.fill"
        case .normal: return "checkmark.circle"
        case .tired:  return "moon.fill"
        case .sore:   return "bandage.fill"
        }
    }

    var intensityMultiplier: Double {
        switch self {
        case .fresh:  return 1.1
        case .normal: return 1.0
        case .tired:  return 0.8
        case .sore:   return 0.6
        }
    }
}

// MARK: - Session & Muscle

enum SessionType: String, Codable, CaseIterable, Identifiable {
    case push           = "Push"
    case pull           = "Pull"
    case legs           = "Legs"
    case upper          = "Upper Body"
    case lower          = "Lower Body"
    case fullBody       = "Full Body"
    case cardio         = "Cardio"
    case hiit           = "HIIT"
    case activeRecovery = "Active Recovery"
    case rest           = "Rest"
    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .push:           return "arrow.up.circle.fill"
        case .pull:           return "arrow.down.circle.fill"
        case .legs:           return "figure.walk"
        case .upper:          return "figure.arms.open"
        case .lower:          return "figure.step.training"
        case .fullBody:       return "figure.highintensity.intervaltraining"
        case .cardio:         return "figure.run"
        case .hiit:           return "bolt.heart.fill"
        case .activeRecovery: return "figure.cooldown"
        case .rest:           return "moon.zzz.fill"
        }
    }
}

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest      = "Chest"
    case back       = "Back"
    case shoulders  = "Shoulders"
    case biceps     = "Biceps"
    case triceps    = "Triceps"
    case quads      = "Quads"
    case hamstrings = "Hamstrings"
    case glutes     = "Glutes"
    case calves     = "Calves"
    case core       = "Core"
    case fullBody   = "Full Body"
    case cardio     = "Cardio"
    var id: String { rawValue }
}

// MARK: - Exercise block

struct ExerciseBlock: Codable, Identifiable {
    var id: String
    var name: String
    var sets: Int
    var repsLow: Int
    var repsHigh: Int
    var restSeconds: Int
    var tempo: String       // e.g. "3-1-2" (eccentric-pause-concentric)
    var cues: [String]
    var muscleGroup: MuscleGroup
    var equipment: Equipment

    var repsLabel: String {
        repsLow == repsHigh ? "\(repsLow)" : "\(repsLow)–\(repsHigh)"
    }

    var setsRepsLabel: String { "\(sets) × \(repsLabel)" }

    var restLabel: String {
        let m = restSeconds / 60
        let s = restSeconds % 60
        if m > 0 { return s > 0 ? "\(m)m \(s)s" : "\(m)m" }
        return "\(s)s"
    }
}

// MARK: - Workout day

struct WorkoutDay: Codable, Identifiable {
    var id: String
    var weekdayIndex: Int       // 1 = Monday … 7 = Sunday
    var weekdayName: String
    var sessionType: SessionType
    var exercises: [ExerciseBlock]
    var estimatedMinutes: Int
    var estimatedCalories: Int
    var notes: String
}

// MARK: - Weekly plan

struct WorkoutPlan: Codable, Identifiable {
    var id: String
    var userId: String
    var createdAt: Date
    var goal: FitnessGoal
    var experience: ExperienceLevel
    var equipment: [Equipment]
    var days: [WorkoutDay]
    var splitName: String
    var weeklyVolume: Int        // total sets across all training days
    var notes: String
}
