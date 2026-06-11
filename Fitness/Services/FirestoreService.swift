// MARK: - FirestoreService
// Active when FirebaseFirestore is linked via SPM.
// SPM: https://github.com/firebase/firebase-ios-sdk  targets: FirebaseFirestore, FirebaseFirestoreSwift
//
// Collection layout
// ─────────────────────────────────────────────────────────────────
//  users/{uid}                           UserProfile document
//  users/{uid}/meta/streak               StreakRecord document
//  users/{uid}/health/{dateKey}          HealthSnapshot document
//
//  goals/{uid}                           Goal summary (fitnessGoal, weeklyMinutes, calorieGoal)
//
//  workouts/{uid}/sessions/{sessionId}   WorkoutSession
//  workouts/{uid}/plans/{planId}         WorkoutPlan
//
//  nutrition_logs/{uid}/entries/{id}     NutritionEntry
//  nutrition_logs/{uid}/water/{id}       WaterEntry
//
//  achievements/{uid}                    { items: [ Achievement ] }
//
//  chat_history/{uid}/messages/{id}      ChatMessage
// ─────────────────────────────────────────────────────────────────

#if canImport(FirebaseFirestore)
import FirebaseFirestore
import Foundation

final class FirestoreService: DatabaseServiceProtocol {

    private let db = Firestore.firestore()

    // Dates stored as secondsSince1970 Double so Firestore range queries work.
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

    // MARK: - Codable ↔ Firestore helpers

    private func asDict<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try encoder.encode(value)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FSError.encodingFailed
        }
        return dict
    }

    private func from<T: Decodable>(_ type: T.Type, _ dict: [String: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try decoder.decode(type, from: data)
    }

    private enum FSError: Error { case encodingFailed }

    // MARK: - User profile
    // users/{uid}

    func saveUserProfile(_ profile: UserProfile) async throws {
        let data = try asDict(profile)
        try await db.collection("users").document(profile.id).setData(data, merge: true)

        // Mirror goal fields to the goals collection for independent goal tracking.
        let goalData: [String: Any] = [
            "fitnessGoal":           profile.fitnessGoal.rawValue,
            "weeklyWorkoutMinutes":  profile.workoutMinutes,
            "calorieGoal":           profile.recommendedDailyCalories,
            "activityLevel":         profile.activityLevel.rawValue,
        ]
        try await db.collection("goals").document(profile.id).setData(goalData, merge: true)
    }

    func fetchUserProfile(uid: String) async throws -> UserProfile? {
        let doc = try await db.collection("users").document(uid).getDocument()
        guard let data = doc.data() else { return nil }
        return try from(UserProfile.self, data)
    }

    // MARK: - Workout sessions
    // workouts/{uid}/sessions/{sessionId}

    func saveWorkoutSession(_ session: WorkoutSession) async throws {
        let data = try asDict(session)
        try await db.collection("workouts").document(session.userId)
            .collection("sessions").document(session.id).setData(data)
    }

    func fetchWorkoutHistory(uid: String, limit: Int) async throws -> [WorkoutSession] {
        let snap = try await db.collection("workouts").document(uid)
            .collection("sessions")
            .order(by: "date", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snap.documents.compactMap { try? from(WorkoutSession.self, $0.data()) }
    }

    // MARK: - Nutrition entries
    // nutrition_logs/{uid}/entries/{id}

    func saveNutritionEntry(_ entry: NutritionEntry) async throws {
        let data = try asDict(entry)
        try await db.collection("nutrition_logs").document(entry.userId)
            .collection("entries").document(entry.id).setData(data)
    }

    func fetchNutritionEntries(uid: String, date: Date) async throws -> [NutritionEntry] {
        let start = Calendar.current.startOfDay(for: date).timeIntervalSince1970
        let end   = start + 86_400
        let snap = try await db.collection("nutrition_logs").document(uid)
            .collection("entries")
            .whereField("date", isGreaterThanOrEqualTo: start)
            .whereField("date", isLessThan: end)
            .getDocuments()
        return snap.documents.compactMap { try? from(NutritionEntry.self, $0.data()) }
    }

    // MARK: - Water entries
    // nutrition_logs/{uid}/water/{id}

    func saveWaterEntry(_ entry: WaterEntry) async throws {
        let data = try asDict(entry)
        try await db.collection("nutrition_logs").document(entry.userId)
            .collection("water").document(entry.id).setData(data)
    }

    func fetchWaterEntries(uid: String, date: Date) async throws -> [WaterEntry] {
        let start = Calendar.current.startOfDay(for: date).timeIntervalSince1970
        let end   = start + 86_400
        let snap = try await db.collection("nutrition_logs").document(uid)
            .collection("water")
            .whereField("date", isGreaterThanOrEqualTo: start)
            .whereField("date", isLessThan: end)
            .getDocuments()
        return snap.documents.compactMap { try? from(WaterEntry.self, $0.data()) }
    }

    // MARK: - Streak
    // users/{uid}/meta/streak

    func saveStreak(_ streak: StreakRecord) async throws {
        let data = try asDict(streak)
        try await db.collection("users").document(streak.userId)
            .collection("meta").document("streak").setData(data)
    }

    func fetchStreak(uid: String) async throws -> StreakRecord? {
        let doc = try await db.collection("users").document(uid)
            .collection("meta").document("streak").getDocument()
        guard let data = doc.data() else { return nil }
        return try from(StreakRecord.self, data)
    }

    // MARK: - Chat history
    // chat_history/{uid}/messages/{id}

    func saveChatHistory(_ messages: [ChatMessage], uid: String) async throws {
        let batch  = db.batch()
        let colRef = db.collection("chat_history").document(uid).collection("messages")
        for msg in messages {
            let data = try asDict(msg)
            batch.setData(data, forDocument: colRef.document(msg.id))
        }
        try await batch.commit()
    }

    func fetchChatHistory(uid: String) async throws -> [ChatMessage] {
        let snap = try await db.collection("chat_history").document(uid)
            .collection("messages")
            .order(by: "timestamp")
            .getDocuments()
        return snap.documents.compactMap { try? from(ChatMessage.self, $0.data()) }
    }

    // MARK: - Health snapshots
    // users/{uid}/health/{dateKey}

    func saveHealthSnapshot(_ snapshot: HealthSnapshot) async throws {
        let dateKey = DateFormatter.snapshotDate.string(from: snapshot.date)
        let data    = try asDict(snapshot)
        try await db.collection("users").document(snapshot.userId)
            .collection("health").document(dateKey).setData(data)
    }

    func fetchHealthSnapshot(uid: String, date: Date) async throws -> HealthSnapshot? {
        let dateKey = DateFormatter.snapshotDate.string(from: date)
        let doc = try await db.collection("users").document(uid)
            .collection("health").document(dateKey).getDocument()
        guard let data = doc.data() else { return nil }
        return try from(HealthSnapshot.self, data)
    }

    // MARK: - Workout plan
    // workouts/{uid}/plans/{planId}

    func saveWorkoutPlan(_ plan: WorkoutPlan) async throws {
        let data = try asDict(plan)
        try await db.collection("workouts").document(plan.userId)
            .collection("plans").document(plan.id).setData(data)
    }

    func fetchLatestWorkoutPlan(uid: String) async throws -> WorkoutPlan? {
        let snap = try await db.collection("workouts").document(uid)
            .collection("plans")
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .getDocuments()
        guard let doc = snap.documents.first else { return nil }
        return try from(WorkoutPlan.self, doc.data())
    }

    // MARK: - Achievements
    // achievements/{uid}  →  { items: [ encoded Achievement dicts ] }

    func saveAchievements(_ achievements: [Achievement], uid: String) async throws {
        let items = try achievements.map { try asDict($0) }
        try await db.collection("achievements").document(uid).setData(["items": items])
    }

    func fetchAchievements(uid: String) async throws -> [Achievement] {
        let doc = try await db.collection("achievements").document(uid).getDocument()
        guard let data = doc.data(),
              let items = data["items"] as? [[String: Any]] else { return [] }
        return items.compactMap { try? from(Achievement.self, $0) }
    }

    // MARK: - Day counts (for achievement evaluation)

    func countNutritionDays(uid: String) async throws -> Int {
        let snap = try await db.collection("nutrition_logs").document(uid)
            .collection("entries").getDocuments()
        let days = snap.documents.compactMap { doc -> Date? in
            guard let ts = doc.data()["date"] as? TimeInterval else { return nil }
            return Date(timeIntervalSince1970: ts)
        }
        return Set(days.map { Calendar.current.startOfDay(for: $0) }).count
    }

    func countWaterDays(uid: String) async throws -> Int {
        let snap = try await db.collection("nutrition_logs").document(uid)
            .collection("water").getDocuments()
        let days = snap.documents.compactMap { doc -> Date? in
            guard let ts = doc.data()["date"] as? TimeInterval else { return nil }
            return Date(timeIntervalSince1970: ts)
        }
        return Set(days.map { Calendar.current.startOfDay(for: $0) }).count
    }
}
#endif
