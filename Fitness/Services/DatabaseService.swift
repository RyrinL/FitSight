import Foundation

// MARK: - Protocol
// Replace LocalDatabaseService with FirestoreService once Firebase SDK is added.
// SPM: https://github.com/firebase/firebase-ios-sdk  packages: FirebaseFirestore, FirebaseFirestoreSwift

protocol DatabaseServiceProtocol {
    func saveUserProfile(_ profile: UserProfile) async throws
    func fetchUserProfile(uid: String) async throws -> UserProfile?
    func saveWorkoutSession(_ session: WorkoutSession) async throws
    func fetchWorkoutHistory(uid: String, limit: Int) async throws -> [WorkoutSession]
    func saveNutritionEntry(_ entry: NutritionEntry) async throws
    func fetchNutritionEntries(uid: String, date: Date) async throws -> [NutritionEntry]
    func saveWaterEntry(_ entry: WaterEntry) async throws
    func fetchWaterEntries(uid: String, date: Date) async throws -> [WaterEntry]
    func saveStreak(_ streak: StreakRecord) async throws
    func fetchStreak(uid: String) async throws -> StreakRecord?
    func saveChatHistory(_ messages: [ChatMessage], uid: String) async throws
    func fetchChatHistory(uid: String) async throws -> [ChatMessage]

    // MARK: Health snapshots
    // One upserted record per user per calendar day.
    // Firestore swap-in: use setData(mergeFields:) so concurrent writes stay safe.
    func saveHealthSnapshot(_ snapshot: HealthSnapshot) async throws
    func fetchHealthSnapshot(uid: String, date: Date) async throws -> HealthSnapshot?

    // MARK: Workout plan
    // Firestore swap-in: db.collection("users").document(uid).collection("plans").document(plan.id)
    func saveWorkoutPlan(_ plan: WorkoutPlan) async throws
    func fetchLatestWorkoutPlan(uid: String) async throws -> WorkoutPlan?

    // MARK: Achievements
    func saveAchievements(_ achievements: [Achievement], uid: String) async throws
    func fetchAchievements(uid: String) async throws -> [Achievement]

    // MARK: Day counts (for achievement evaluation)
    func countNutritionDays(uid: String) async throws -> Int
    func countWaterDays(uid: String) async throws -> Int
}

// MARK: - Local (UserDefaults) implementation

final class LocalDatabaseService: DatabaseServiceProtocol {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private func key(_ path: String) -> String { "fitsight.\(path)" }

    func saveUserProfile(_ profile: UserProfile) async throws {
        let data = try encoder.encode(profile)
        UserDefaults.standard.set(data, forKey: key("profile.\(profile.id)"))
    }

    func fetchUserProfile(uid: String) async throws -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: key("profile.\(uid)")) else { return nil }
        return try decoder.decode(UserProfile.self, from: data)
    }

    func saveWorkoutSession(_ session: WorkoutSession) async throws {
        var sessions = (try? await fetchWorkoutHistory(uid: session.userId, limit: 500)) ?? []
        sessions.removeAll { $0.id == session.id }
        sessions.insert(session, at: 0)
        let data = try encoder.encode(sessions)
        UserDefaults.standard.set(data, forKey: key("workouts.\(session.userId)"))
    }

    func fetchWorkoutHistory(uid: String, limit: Int) async throws -> [WorkoutSession] {
        guard let data = UserDefaults.standard.data(forKey: key("workouts.\(uid)")) else { return [] }
        let all = try decoder.decode([WorkoutSession].self, from: data)
        return Array(all.prefix(limit))
    }

    func saveNutritionEntry(_ entry: NutritionEntry) async throws {
        var entries = (try? await fetchAllNutrition(uid: entry.userId)) ?? []
        entries.removeAll { $0.id == entry.id }
        entries.append(entry)
        let data = try encoder.encode(entries)
        UserDefaults.standard.set(data, forKey: key("nutrition.\(entry.userId)"))
    }

    func fetchNutritionEntries(uid: String, date: Date) async throws -> [NutritionEntry] {
        let all = (try? await fetchAllNutrition(uid: uid)) ?? []
        return all.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private func fetchAllNutrition(uid: String) async throws -> [NutritionEntry] {
        guard let data = UserDefaults.standard.data(forKey: key("nutrition.\(uid)")) else { return [] }
        return try decoder.decode([NutritionEntry].self, from: data)
    }

    func saveWaterEntry(_ entry: WaterEntry) async throws {
        var entries = (try? await fetchAllWater(uid: entry.userId)) ?? []
        entries.append(entry)
        let data = try encoder.encode(entries)
        UserDefaults.standard.set(data, forKey: key("water.\(entry.userId)"))
    }

    func fetchWaterEntries(uid: String, date: Date) async throws -> [WaterEntry] {
        let all = (try? await fetchAllWater(uid: uid)) ?? []
        return all.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private func fetchAllWater(uid: String) async throws -> [WaterEntry] {
        guard let data = UserDefaults.standard.data(forKey: key("water.\(uid)")) else { return [] }
        return try decoder.decode([WaterEntry].self, from: data)
    }

    func saveStreak(_ streak: StreakRecord) async throws {
        let data = try encoder.encode(streak)
        UserDefaults.standard.set(data, forKey: key("streak.\(streak.userId)"))
    }

    func fetchStreak(uid: String) async throws -> StreakRecord? {
        guard let data = UserDefaults.standard.data(forKey: key("streak.\(uid)")) else { return nil }
        return try decoder.decode(StreakRecord.self, from: data)
    }

    func saveChatHistory(_ messages: [ChatMessage], uid: String) async throws {
        let data = try encoder.encode(messages)
        UserDefaults.standard.set(data, forKey: key("chat.\(uid)"))
    }

    func fetchChatHistory(uid: String) async throws -> [ChatMessage] {
        guard let data = UserDefaults.standard.data(forKey: key("chat.\(uid)")) else { return [] }
        return try decoder.decode([ChatMessage].self, from: data)
    }

    // MARK: Health snapshots

    func saveHealthSnapshot(_ snapshot: HealthSnapshot) async throws {
        // Key is per-user per-day so writing it again replaces the earlier value (upsert).
        let dateKey = DateFormatter.snapshotDate.string(from: snapshot.date)
        let data = try encoder.encode(snapshot)
        UserDefaults.standard.set(data, forKey: key("health.\(snapshot.userId).\(dateKey)"))
    }

    func fetchHealthSnapshot(uid: String, date: Date) async throws -> HealthSnapshot? {
        let dateKey = DateFormatter.snapshotDate.string(from: date)
        guard let data = UserDefaults.standard.data(forKey: key("health.\(uid).\(dateKey)")) else { return nil }
        return try decoder.decode(HealthSnapshot.self, from: data)
    }

    // MARK: Workout plan — keyed per user; only latest plan is stored locally

    func saveWorkoutPlan(_ plan: WorkoutPlan) async throws {
        let data = try encoder.encode(plan)
        UserDefaults.standard.set(data, forKey: key("plan.\(plan.userId)"))
    }

    func fetchLatestWorkoutPlan(uid: String) async throws -> WorkoutPlan? {
        guard let data = UserDefaults.standard.data(forKey: key("plan.\(uid)")) else { return nil }
        return try decoder.decode(WorkoutPlan.self, from: data)
    }

    // MARK: Achievements

    func saveAchievements(_ achievements: [Achievement], uid: String) async throws {
        let data = try encoder.encode(achievements)
        UserDefaults.standard.set(data, forKey: key("achievements.\(uid)"))
    }

    func fetchAchievements(uid: String) async throws -> [Achievement] {
        guard let data = UserDefaults.standard.data(forKey: key("achievements.\(uid)")) else { return [] }
        return try decoder.decode([Achievement].self, from: data)
    }

    // MARK: Day counts

    func countNutritionDays(uid: String) async throws -> Int {
        let all = (try? await fetchAllNutrition(uid: uid)) ?? []
        let uniqueDays = Set(all.map { Calendar.current.startOfDay(for: $0.date) })
        return uniqueDays.count
    }

    func countWaterDays(uid: String) async throws -> Int {
        let all = (try? await fetchAllWater(uid: uid)) ?? []
        let uniqueDays = Set(all.map { Calendar.current.startOfDay(for: $0.date) })
        return uniqueDays.count
    }
}
