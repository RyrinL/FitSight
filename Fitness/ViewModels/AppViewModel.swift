import Foundation
import SwiftUI

// MARK: - Service factory
// Returns Firebase implementations when the SDK is linked, local otherwise.

private func makeAuthService() -> any AuthServiceProtocol {
    #if canImport(FirebaseAuth)
    return FirebaseAuthService()
    #else
    return LocalAuthService()
    #endif
}

private func makeDBService() -> any DatabaseServiceProtocol {
    #if canImport(FirebaseFirestore)
    return FirestoreService()
    #elseif canImport(FirebaseDatabase)
    return RealtimeDatabaseService()
    #else
    return LocalDatabaseService()
    #endif
}

// MARK: - AppViewModel

@MainActor
final class AppViewModel: ObservableObject {
    @Published var isAuthenticated  = false
    @Published var currentUser: AppUser?
    @Published var profile: UserProfile?
    @Published var streak: StreakRecord = .empty(userId: "")
    @Published var isLoadingProfile = false
    @Published var profileComplete  = false
    @Published var achievements: [Achievement]      = []
    @Published var newlyUnlocked: [Achievement]     = []

    let auth: any AuthServiceProtocol
    let db:   any DatabaseServiceProtocol
    let healthKit    = HealthKitService()
    let notifications = NotificationService.shared

    init() {
        auth = makeAuthService()
        db   = makeDBService()

        setupHealthKitSync()

        if let user = auth.currentUser {
            currentUser     = user
            isAuthenticated = true
            Task { await loadProfile(uid: user.uid) }
        }
    }

    // MARK: - Auth

    func signIn(email: String, password: String) async throws {
        let user = try await auth.signIn(email: email, password: password)
        currentUser     = user
        isAuthenticated = true
        setupHealthKitSync()
        await loadProfile(uid: user.uid)
        CrashlyticsService.setUser(uid: user.uid)
        AnalyticsService.setUser(uid: user.uid)
    }

    func signUp(email: String, password: String) async throws {
        guard EmailDomainPolicy.isAllowed(email) else { throw AuthError.emailDomainNotAllowed }
        let user = try await auth.signUp(email: email, password: password)
        currentUser     = user
        isAuthenticated = true
        setupHealthKitSync()
        CrashlyticsService.setUser(uid: user.uid)
        AnalyticsService.setUser(uid: user.uid)
    }

    func signOut() {
        healthKit.stopObservers()
        healthKit.onDataRefreshed = nil
        try? auth.signOut()
        currentUser     = nil
        profile         = nil
        isAuthenticated = false
        profileComplete = false
        achievements    = []
        newlyUnlocked   = []
    }

    // MARK: - Profile

    func saveProfile(_ p: UserProfile) async {
        profile         = p
        profileComplete = true
        try? await db.saveUserProfile(p)
        await markActiveAndSaveStreak(uid: p.id)
    }

    func loadProfile(uid: String) async {
        isLoadingProfile = true
        defer { isLoadingProfile = false }

        async let profileResult      = db.fetchUserProfile(uid: uid)
        async let streakResult       = db.fetchStreak(uid: uid)
        async let achievementsResult = db.fetchAchievements(uid: uid)

        profile         = try? await profileResult
        profileComplete = profile != nil
        streak          = (try? await streakResult)       ?? .empty(userId: uid)
        achievements    = (try? await achievementsResult) ?? []
    }

    // MARK: - Streak

    func markActiveAndSaveStreak(uid: String) async {
        var s = streak
        s.markActiveToday()
        streak = s
        try? await db.saveStreak(s)
        if s.currentStreak > 0 {
            Task { await notifications.scheduleStreakWarning(currentStreak: s.currentStreak) }
        }
    }

    // MARK: - Achievements

    func refreshAchievements(uid: String, sessions: [WorkoutSession]) async {
        async let existingResult  = db.fetchAchievements(uid: uid)
        async let nutritionResult = db.countNutritionDays(uid: uid)
        async let waterResult     = db.countWaterDays(uid: uid)

        let existing      = (try? await existingResult)  ?? achievements
        let nutritionDays = (try? await nutritionResult) ?? 0
        let waterDays     = (try? await waterResult)     ?? 0

        let stats = AchievementEngine.Stats(
            streak: streak,
            sessions: sessions,
            nutritionDaysLogged: nutritionDays,
            waterDaysLogged: waterDays
        )

        let updated    = AchievementEngine.evaluate(stats: stats, existing: existing)
        let justEarned = AchievementEngine.newlyEarned(updated: updated, previous: existing)

        achievements = updated

        if !justEarned.isEmpty {
            newlyUnlocked = justEarned
            FitHaptic.success()
            for a in justEarned {
                AnalyticsService.logAchievementEarned(id: a.id, tier: a.tier.rawValue)
            }
        }

        try? await db.saveAchievements(updated, uid: uid)
    }

    func dismissUnlockBanner() {
        newlyUnlocked = []
    }

    // MARK: - HealthKit sync

    private func setupHealthKitSync() {
        healthKit.onDataRefreshed = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, let uid = self.currentUser?.uid else { return }
                await self.syncHealthSnapshot(uid: uid)
            }
        }
    }

    private func syncHealthSnapshot(uid: String) async {
        let snapshot = HealthSnapshot.make(
            userId: uid,
            activeEnergyKcal: healthKit.activeEnergyToday,
            stepsCount: healthKit.stepsToday,
            restingHeartRateBpm: healthKit.restingHeartRate,
            heartRateBpm: healthKit.heartRateToday,
            waterMl: healthKit.waterMlToday,
            workoutMinutes: healthKit.workoutMinutesToday,
            workoutCount: healthKit.workoutCountToday
        )
        try? await db.saveHealthSnapshot(snapshot)
    }
}
