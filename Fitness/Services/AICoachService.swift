import Foundation

enum AIError: LocalizedError {
    case apiError(String)
    var errorDescription: String? {
        if case .apiError(let msg) = self { return "AI Coach: \(msg)" }
        return nil
    }
}

// MARK: - Coach context

struct CoachContext {
    let profile: UserProfile
    let recentWorkouts: [WorkoutSession]
    let streak: StreakRecord
    let activeKcal: Double
    let dailyGoalKcal: Double

    var systemPromptSupplement: String {
        var parts: [String] = []
        parts.append("User: \(profile.fitnessGoal.rawValue) goal, \(profile.experienceLevel.rawValue) level, \(profile.activityLevel.rawValue).")
        parts.append("Equipment: \(profile.availableEquipment.map(\.rawValue).joined(separator: ", ")).")
        parts.append("Workout focus: \(profile.workoutFocus.rawValue), target \(profile.workoutMinutes) min/session.")
        if !recentWorkouts.isEmpty {
            let titles = recentWorkouts.prefix(3).map(\.title).joined(separator: "; ")
            parts.append("Recent workouts: \(titles).")
        }
        let streakWord = streak.currentStreak == 1 ? "day" : "days"
        parts.append("Streak: \(streak.currentStreak) \(streakWord).")
        let pct = dailyGoalKcal > 0 ? Int((activeKcal / dailyGoalKcal) * 100) : 0
        parts.append("Today's active calories: \(Int(activeKcal))/\(Int(dailyGoalKcal)) kcal (\(pct)%).")
        return parts.joined(separator: " ")
    }
}

// MARK: - AICoachService

final class AICoachService {
    static let shared = AICoachService()
    private init() {}

    private let groqKey = Secrets.groqKey.isEmpty
        ? (ProcessInfo.processInfo.environment["GROQ_API_KEY"] ?? "")
        : Secrets.groqKey

    private func systemPrompt(context: CoachContext?) -> String {
        var base = """
        You are FitSight AI Coach, an expert personal trainer and sports nutritionist. \
        Give concise, practical coaching advice grounded in exercise science. \
        Keep responses under 120 words. Be encouraging, specific, and safe. \
        Never provide medical diagnoses or replace professional medical advice.
        """
        if let ctx = context {
            base += "\n\nUser context: \(ctx.systemPromptSupplement)"
        }
        return base
    }

    func send(messages: [ChatMessage], context: CoachContext? = nil) async throws -> String {
        guard !groqKey.isEmpty else {
            return offlineResponse(for: messages.last?.content ?? "")
        }
        return try await sendGroq(messages: messages, context: context)
    }

    // MARK: - Groq

    private func sendGroq(messages: [ChatMessage], context: CoachContext?) async throws -> String {
        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(groqKey)", forHTTPHeaderField: "Authorization")

        var allMessages: [[String: String]] = [
            ["role": "system", "content": systemPrompt(context: context)]
        ]
        allMessages += messages
            .filter { $0.role != .system }
            .map { ["role": $0.role.rawValue, "content": $0.content] }

        let body: [String: Any] = [
            "model": "llama-3.1-8b-instant",
            "max_tokens": 256,
            "messages": allMessages
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let error = json?["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw AIError.apiError(message)
        }

        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        guard let text = message?["content"] as? String else {
            throw AIError.apiError("Empty response from Groq")
        }
        return text
    }

    // MARK: - Weekly plan generation

    /// Generate a full weekly plan via the AI backend. Falls back to the local
    /// RecommendationEngine if there's no API key or the request/decode fails,
    /// so the caller always gets a usable plan.
    func generateWeeklyPlan(profile: UserProfile, recovery: RecoveryStatus) async -> WorkoutPlan {
        guard !groqKey.isEmpty else {
            return RecommendationEngine.weeklyPlan(for: profile)
        }
        do {
            let dto = try await requestPlan(profile: profile, recovery: recovery)
            let plan = Self.makePlan(from: dto, profile: profile)
            // Guard against an empty/degenerate AI response.
            return plan.days.contains { $0.sessionType != .rest } ? plan
                                                                   : RecommendationEngine.weeklyPlan(for: profile)
        } catch {
            return RecommendationEngine.weeklyPlan(for: profile)
        }
    }

    private func requestPlan(profile: UserProfile, recovery: RecoveryStatus) async throws -> AIPlanDTO {
        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(groqKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 30

        let equipment = profile.availableEquipment.isEmpty
            ? Equipment.bodyweight.rawValue
            : profile.availableEquipment.map(\.rawValue).joined(separator: ", ")

        let system = """
        You are an expert strength & conditioning coach. Design a 7-day workout plan as STRICT JSON only \
        (no markdown, no prose). Match this exact shape:
        {
          "splitName": String,
          "notes": String,
          "days": [
            {
              "weekday": "Monday"|...|"Sunday",
              "sessionType": one of ["Push","Pull","Legs","Upper Body","Lower Body","Full Body","Cardio","HIIT","Active Recovery","Rest"],
              "estimatedMinutes": Int,
              "estimatedCalories": Int,
              "notes": String,
              "exercises": [
                {
                  "name": String,
                  "sets": Int,
                  "repsLow": Int,
                  "repsHigh": Int,
                  "restSeconds": Int,
                  "tempo": "3-1-2",
                  "cues": [String],
                  "muscleGroup": one of ["Chest","Back","Shoulders","Biceps","Triceps","Quads","Hamstrings","Glutes","Calves","Core","Full Body","Cardio"],
                  "equipment": one of ["Bodyweight","Dumbbells","Barbell","Kettlebell","Resistance Bands","Pull-up Bar","Cables","Cardio Machine"]
                }
              ]
            }
          ]
        }
        Rules: return EXACTLY 7 days in order Monday→Sunday. Rest days have sessionType "Rest" and an empty exercises array. \
        Only use the equipment the user owns. 3–6 exercises per training day. Vary exercise selection from any previous plan.
        """

        let user = """
        Goal: \(profile.fitnessGoal.rawValue). Experience: \(profile.experienceLevel.rawValue). \
        Activity level: \(profile.activityLevel.rawValue). Focus: \(profile.workoutFocus.rawValue). \
        Target session length: \(profile.workoutMinutes) minutes. \
        Equipment owned: \(equipment). Current recovery state: \(recovery.rawValue). \
        Build the most effective weekly split for this person.
        """

        let body: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "temperature": 0.85,
            "max_tokens": 4096,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let error = json?["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw AIError.apiError(message)
        }

        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        guard let content = message?["content"] as? String,
              let contentData = content.data(using: .utf8) else {
            throw AIError.apiError("Empty plan response")
        }
        return try JSONDecoder().decode(AIPlanDTO.self, from: contentData)
    }

    // MARK: - Offline fallback

    private func offlineResponse(for query: String) -> String {
        let lower = query.lowercased()
        if lower.contains("squat")                            { return "For squats: feet shoulder-width apart, toes slightly out. Drive knees over toes, chest proud, hips below parallel. Control the descent in 3 seconds, explode up." }
        if lower.contains("push")                             { return "For push-ups: hands shoulder-width apart, body in a straight line from head to heels. Lower until chest nearly touches the floor. Keep elbows at 45°, not flared." }
        if lower.contains("protein")                          { return "Aim for 1.6–2.2g of protein per kg of bodyweight daily. Prioritize lean meats, eggs, Greek yogurt, legumes, and protein shakes around workouts." }
        if lower.contains("sleep")                            { return "Prioritize 7–9 hours. Sleep is when muscle is built and hormones reset. Poor sleep increases cortisol and reduces performance by up to 30%." }
        if lower.contains("cardio")                           { return "Zone 2 (conversational pace, 60–70% max HR) 3× per week builds aerobic base and burns fat. Add 1 HIIT session for metabolic conditioning." }
        if lower.contains("recover") || lower.contains("sore") { return "For recovery: prioritize sleep, stay hydrated, do light walking or yoga. Foam roll tight spots. Eat enough protein to repair muscle tissue." }
        if lower.contains("workout") || lower.contains("suggest") { return "A well-structured workout: 5-min warm-up, compound movements first, isolation last, cool-down stretch. Match volume to your recovery status." }
        if lower.contains("motivat")                          { return "Progress is built rep by rep. Every session—no matter how short—compounds over time. You showed up; that's already the hardest part." }
        if lower.contains("nutrition") || lower.contains("eat") { return "Fuel your goal: prioritize whole foods, hit your protein target, and time carbs around workouts. Consistency over perfection." }
        return "I'm your FitSight AI Coach. Ask me about workouts, nutrition, recovery, or your fitness goals!"
    }
}

// MARK: - AI plan decoding

/// Lenient DTOs — the model's JSON is matched defensively and mapped to the
/// strict WorkoutPlan model, defaulting any unrecognised enum values.
private struct AIPlanDTO: Decodable {
    let splitName: String?
    let notes: String?
    let days: [AIDayDTO]?
}

private struct AIDayDTO: Decodable {
    let weekday: String?
    let sessionType: String?
    let estimatedMinutes: Int?
    let estimatedCalories: Int?
    let notes: String?
    let exercises: [AIExerciseDTO]?
}

private struct AIExerciseDTO: Decodable {
    let name: String?
    let sets: Int?
    let repsLow: Int?
    let repsHigh: Int?
    let restSeconds: Int?
    let tempo: String?
    let cues: [String]?
    let muscleGroup: String?
    let equipment: String?
}

extension AICoachService {
    static let weekdayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    fileprivate static func makePlan(from dto: AIPlanDTO, profile: UserProfile) -> WorkoutPlan {
        let aiDays = dto.days ?? []
        let fallbackEquipment = profile.availableEquipment.isEmpty ? [Equipment.bodyweight] : profile.availableEquipment

        let days: [WorkoutDay] = weekdayNames.enumerated().map { i, name in
            let src = i < aiDays.count ? aiDays[i] : nil
            let session = matchSession(src?.sessionType)

            guard session != .rest else {
                return WorkoutDay(
                    id: UUID().uuidString, weekdayIndex: i + 1, weekdayName: name,
                    sessionType: .rest, exercises: [],
                    estimatedMinutes: 0, estimatedCalories: 0,
                    notes: (src?.notes?.isEmpty == false ? src!.notes! : "Rest — let your body recover.")
                )
            }

            let exercises = (src?.exercises ?? []).compactMap { mapExercise($0, default: fallbackEquipment.first ?? .bodyweight) }
            let minutes = max(src?.estimatedMinutes ?? profile.workoutMinutes, 1)
            let calories = src?.estimatedCalories.map { max($0, 0) } ?? Int(Double(minutes) * 7.0)

            return WorkoutDay(
                id: UUID().uuidString, weekdayIndex: i + 1, weekdayName: name,
                sessionType: session, exercises: exercises,
                estimatedMinutes: minutes, estimatedCalories: calories,
                notes: src?.notes ?? ""
            )
        }

        return WorkoutPlan(
            id: UUID().uuidString,
            userId: profile.id,
            createdAt: Date(),
            goal: profile.fitnessGoal,
            experience: profile.experienceLevel,
            equipment: fallbackEquipment,
            days: days,
            splitName: dto.splitName?.isEmpty == false ? dto.splitName! : "AI Custom Plan",
            weeklyVolume: days.reduce(0) { $0 + $1.exercises.reduce(0) { $0 + $1.sets } },
            notes: dto.notes ?? "Generated by FitSight AI Coach."
        )
    }

    private static func mapExercise(_ dto: AIExerciseDTO, default fallbackEquip: Equipment) -> ExerciseBlock? {
        guard let name = dto.name, !name.isEmpty else { return nil }
        let lo = max(dto.repsLow ?? 8, 1)
        let hi = max(dto.repsHigh ?? lo, lo)
        return ExerciseBlock(
            id: UUID().uuidString,
            name: name,
            sets: max(dto.sets ?? 3, 1),
            repsLow: lo,
            repsHigh: hi,
            restSeconds: max(dto.restSeconds ?? 60, 0),
            tempo: dto.tempo ?? "2-0-1",
            cues: dto.cues ?? [],
            muscleGroup: matchMuscle(dto.muscleGroup),
            equipment: matchEquipment(dto.equipment) ?? fallbackEquip
        )
    }

    private static func matchSession(_ raw: String?) -> SessionType {
        guard let raw else { return .rest }
        let key = raw.lowercased().trimmingCharacters(in: .whitespaces)
        if let exact = SessionType(rawValue: raw) { return exact }
        return SessionType.allCases.first { $0.rawValue.lowercased() == key }
            ?? SessionType.allCases.first { key.contains($0.rawValue.lowercased()) || $0.rawValue.lowercased().contains(key) }
            ?? .fullBody
    }

    private static func matchMuscle(_ raw: String?) -> MuscleGroup {
        guard let raw else { return .fullBody }
        return MuscleGroup(rawValue: raw)
            ?? MuscleGroup.allCases.first { $0.rawValue.lowercased() == raw.lowercased() }
            ?? .fullBody
    }

    private static func matchEquipment(_ raw: String?) -> Equipment? {
        guard let raw else { return nil }
        return Equipment(rawValue: raw)
            ?? Equipment.allCases.first { $0.rawValue.lowercased() == raw.lowercased() }
    }
}
