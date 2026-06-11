import Foundation

struct WorkoutSession: Codable, Identifiable {
    var id: String
    var userId: String
    var title: String
    var date: Date
    var durationMinutes: Int
    var caloriesBurned: Int
    var exerciseType: String
    var notes: String
    var formScore: Int?    // 0-100 from camera coach

    static func new(userId: String, title: String, minutes: Int, calories: Int, type: String) -> WorkoutSession {
        WorkoutSession(
            id: UUID().uuidString, userId: userId,
            title: title, date: Date(),
            durationMinutes: minutes, caloriesBurned: calories,
            exerciseType: type, notes: "", formScore: nil
        )
    }
}

struct DailyMetric: Identifiable {
    let day: String
    let value: Double
    var id: String { day }
}

struct WorkoutRecommendation: Identifiable {
    let title: String
    let subtitle: String
    let minutes: Int
    let calories: Int
    let intensity: String
    let symbolName: String
    let exercises: [ExerciseBlock]
    var id: String { title }

    // Flat text summary derived from structured exercises for backward-compatible display
    var steps: [String] {
        exercises.map { "\($0.setsRepsLabel)  \($0.name)" }
    }
}

enum HealthAuthorizationState {
    case notRequested, authorized, denied, unavailable
}

enum CameraPermission {
    case unknown, authorized, denied, unavailable
}

enum TrackedExercise: String, CaseIterable, Identifiable {
    case squat = "Squat"
    case pushUp = "Push-up"
    case lunge = "Lunge"
    case plank = "Plank"
    var id: String { rawValue }
}

enum FormSeverity {
    case good       // mint — form is correct
    case caution    // orange — minor deviation
    case error      // red — must correct
}

struct FormCue {
    let text: String
    let isRepBottom: Bool
    var severity: FormSeverity = .caution
    var formScore: Int = 50         // 0–100
}
