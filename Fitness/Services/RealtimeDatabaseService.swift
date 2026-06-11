// MARK: - RealtimeDatabaseService
// Active when FirebaseDatabase is linked via SPM.
// SPM: https://github.com/firebase/firebase-ios-sdk  target: FirebaseDatabase
//
// Database URL: https://fitsight-9ee9c-default-rtdb.asia-southeast1.firebasedatabase.app/
//
// Node layout (mirrors the Firestore collection layout)
// ─────────────────────────────────────────────────────────────────
//  users/{uid}/profile                 UserProfile
//  users/{uid}/streak                  StreakRecord
//  users/{uid}/health/{dateKey}        HealthSnapshot   (dateKey = "yyyy-MM-dd")
//
//  goals/{uid}                         Goal summary fields
//
//  workouts/{uid}/sessions/{sessionId} WorkoutSession
//  workouts/{uid}/plans/{planId}       WorkoutPlan
//
//  nutrition_logs/{uid}/entries/{id}   NutritionEntry
//  nutrition_logs/{uid}/water/{id}     WaterEntry
//
//  achievements/{uid}/items/{index}    Achievement
//
//  chat_history/{uid}/messages/{id}    ChatMessage
// ─────────────────────────────────────────────────────────────────
//
// Date range queries (nutrition, water) require the child "date"
// to be indexed in Firebase Console:
//   Database → Rules → add  ".indexOn": ["date"]  under the relevant node

#if canImport(FirebaseDatabase)
import FirebaseDatabase
import Foundation

final class RealtimeDatabaseService: DatabaseServiceProtocol {

    // MARK: - Root reference

    private let root: DatabaseReference = Database.database(
        url: "https://fitsight-9ee9c-default-rtdb.asia-southeast1.firebasedatabase.app/"
    ).reference()

    // MARK: - Codable helpers
    //
    // Dates are stored as secondsSince1970 (Double) so Firebase range queries work
    // and so the encoding matches FirestoreService for portability.

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    private func toDict<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try encoder.encode(value)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RTDBError.encodingFailed
        }
        return dict
    }

    private func decode<T: Decodable>(_ type: T.Type, from snap: DataSnapshot) throws -> T {
        guard let raw = snap.value as? [String: Any] else { throw RTDBError.noData }
        let data = try JSONSerialization.data(withJSONObject: raw)
        return try decoder.decode(type, from: data)
    }

    private func decodeChildren<T: Decodable>(_ type: T.Type, from snap: DataSnapshot) -> [T] {
        snap.children.compactMap { child in
            guard let childSnap = child as? DataSnapshot,
                  let raw  = childSnap.value as? [String: Any],
                  let data = try? JSONSerialization.data(withJSONObject: raw),
                  let val  = try? decoder.decode(type, from: data)
            else { return nil }
            return val
        }
    }

    // setValue has no async variant in the SDK — wrap with a continuation.
    private func write(_ dict: Any, at ref: DatabaseReference) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            ref.setValue(dict) { error, _ in
                if let error { cont.resume(throwing: error) }
                else         { cont.resume() }
            }
        }
    }

    private enum RTDBError: Error { case encodingFailed, noData }

    // MARK: - User profile
    // users/{uid}/profile

    func saveUserProfile(_ profile: UserProfile) async throws {
        try await write(try toDict(profile),
                        at: root.child("users/\(profile.id)/profile"))
        let goalDict: [String: Any] = [
            "fitnessGoal":          profile.fitnessGoal.rawValue,
            "weeklyWorkoutMinutes": profile.workoutMinutes,
            "calorieGoal":          profile.recommendedDailyCalories,
            "activityLevel":        profile.activityLevel.rawValue,
        ]
        try await write(goalDict, at: root.child("goals/\(profile.id)"))
    }

    func fetchUserProfile(uid: String) async throws -> UserProfile? {
        let snap = try await root.child("users/\(uid)/profile").getData()
        guard snap.exists() else { return nil }
        return try decode(UserProfile.self, from: snap)
    }

    // MARK: - Workout sessions
    // workouts/{uid}/sessions/{sessionId}

    func saveWorkoutSession(_ session: WorkoutSession) async throws {
        try await write(try toDict(session),
                        at: root.child("workouts/\(session.userId)/sessions/\(session.id)"))
    }

    func fetchWorkoutHistory(uid: String, limit: Int) async throws -> [WorkoutSession] {
        // queryOrdered+queryLimited returns the last N by ascending date value.
        let snap = try await root.child("workouts/\(uid)/sessions")
            .queryOrdered(byChild: "date")
            .queryLimited(toLast: UInt(limit))
            .getData()
        guard snap.exists() else { return [] }
        return decodeChildren(WorkoutSession.self, from: snap)
            .sorted { $0.date > $1.date }
    }

    // MARK: - Nutrition entries
    // nutrition_logs/{uid}/entries/{id}
    // Requires Firebase index: { ".indexOn": ["date"] } under nutrition_logs/{uid}/entries

    func saveNutritionEntry(_ entry: NutritionEntry) async throws {
        try await write(try toDict(entry),
                        at: root.child("nutrition_logs/\(entry.userId)/entries/\(entry.id)"))
    }

    func fetchNutritionEntries(uid: String, date: Date) async throws -> [NutritionEntry] {
        let start = Calendar.current.startOfDay(for: date).timeIntervalSince1970
        let end   = start + 86_400
        let snap = try await root.child("nutrition_logs/\(uid)/entries")
            .queryOrdered(byChild: "date")
            .queryStarting(atValue: start)
            .queryEnding(atValue: end - 1)
            .getData()
        guard snap.exists() else { return [] }
        return decodeChildren(NutritionEntry.self, from: snap)
    }

    // MARK: - Water entries
    // nutrition_logs/{uid}/water/{id}

    func saveWaterEntry(_ entry: WaterEntry) async throws {
        try await write(try toDict(entry),
                        at: root.child("nutrition_logs/\(entry.userId)/water/\(entry.id)"))
    }

    func fetchWaterEntries(uid: String, date: Date) async throws -> [WaterEntry] {
        let start = Calendar.current.startOfDay(for: date).timeIntervalSince1970
        let end   = start + 86_400
        let snap = try await root.child("nutrition_logs/\(uid)/water")
            .queryOrdered(byChild: "date")
            .queryStarting(atValue: start)
            .queryEnding(atValue: end - 1)
            .getData()
        guard snap.exists() else { return [] }
        return decodeChildren(WaterEntry.self, from: snap)
    }

    // MARK: - Streak
    // users/{uid}/streak

    func saveStreak(_ streak: StreakRecord) async throws {
        try await write(try toDict(streak),
                        at: root.child("users/\(streak.userId)/streak"))
    }

    func fetchStreak(uid: String) async throws -> StreakRecord? {
        let snap = try await root.child("users/\(uid)/streak").getData()
        guard snap.exists() else { return nil }
        return try decode(StreakRecord.self, from: snap)
    }

    // MARK: - Chat history
    // chat_history/{uid}/messages/{id}

    func saveChatHistory(_ messages: [ChatMessage], uid: String) async throws {
        var dict: [String: Any] = [:]
        for msg in messages {
            dict[msg.id] = try toDict(msg)
        }
        try await write(dict, at: root.child("chat_history/\(uid)/messages"))
    }

    func fetchChatHistory(uid: String) async throws -> [ChatMessage] {
        let snap = try await root.child("chat_history/\(uid)/messages")
            .queryOrdered(byChild: "timestamp")
            .getData()
        guard snap.exists() else { return [] }
        return decodeChildren(ChatMessage.self, from: snap)
    }

    // MARK: - Health snapshots
    // users/{uid}/health/{dateKey}   dateKey = "yyyy-MM-dd"

    func saveHealthSnapshot(_ snapshot: HealthSnapshot) async throws {
        let dateKey = DateFormatter.snapshotDate.string(from: snapshot.date)
        try await write(try toDict(snapshot),
                        at: root.child("users/\(snapshot.userId)/health/\(dateKey)"))
    }

    func fetchHealthSnapshot(uid: String, date: Date) async throws -> HealthSnapshot? {
        let dateKey = DateFormatter.snapshotDate.string(from: date)
        let snap = try await root.child("users/\(uid)/health/\(dateKey)").getData()
        guard snap.exists() else { return nil }
        return try decode(HealthSnapshot.self, from: snap)
    }

    // MARK: - Workout plan
    // workouts/{uid}/plans/{planId}

    func saveWorkoutPlan(_ plan: WorkoutPlan) async throws {
        try await write(try toDict(plan),
                        at: root.child("workouts/\(plan.userId)/plans/\(plan.id)"))
    }

    func fetchLatestWorkoutPlan(uid: String) async throws -> WorkoutPlan? {
        let snap = try await root.child("workouts/\(uid)/plans")
            .queryOrdered(byChild: "createdAt")
            .queryLimited(toLast: 1)
            .getData()
        guard snap.exists() else { return nil }
        return decodeChildren(WorkoutPlan.self, from: snap).first
    }

    // MARK: - Achievements
    // achievements/{uid}/items — stored as a keyed dictionary (index → Achievement)

    func saveAchievements(_ achievements: [Achievement], uid: String) async throws {
        var dict: [String: Any] = [:]
        for (i, a) in achievements.enumerated() {
            dict["\(i)"] = try toDict(a)
        }
        try await write(dict, at: root.child("achievements/\(uid)/items"))
    }

    func fetchAchievements(uid: String) async throws -> [Achievement] {
        let snap = try await root.child("achievements/\(uid)/items").getData()
        guard snap.exists() else { return [] }
        return decodeChildren(Achievement.self, from: snap)
    }

    // MARK: - Day counts (for achievement evaluation)

    func countNutritionDays(uid: String) async throws -> Int {
        let snap = try await root.child("nutrition_logs/\(uid)/entries").getData()
        guard snap.exists() else { return 0 }
        let entries = decodeChildren(NutritionEntry.self, from: snap)
        return Set(entries.map { Calendar.current.startOfDay(for: $0.date) }).count
    }

    func countWaterDays(uid: String) async throws -> Int {
        let snap = try await root.child("nutrition_logs/\(uid)/water").getData()
        guard snap.exists() else { return 0 }
        let entries = decodeChildren(WaterEntry.self, from: snap)
        return Set(entries.map { Calendar.current.startOfDay(for: $0.date) }).count
    }
}
#endif
