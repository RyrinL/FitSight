import Foundation

// MARK: - HealthSnapshot
// A daily health summary persisted to the database after every HealthKit refresh.
// One snapshot per user per calendar day; the record is upserted (not appended).
//
// Firestore path (when Firebase is wired in):
//   users/{uid}/healthSnapshots/{dateKey}   where dateKey = "yyyy-MM-dd"

struct HealthSnapshot: Codable, Identifiable {
    var id: String                  // "{uid}_{dateKey}"
    var userId: String
    var date: Date
    var activeEnergyKcal: Double    // kcal — food calorie (1 kcal = 1 000 cal)
    var stepsCount: Int
    var restingHeartRateBpm: Double // last resting-HR sample of the day
    var heartRateBpm: Double        // average heart rate across all samples today
    var waterMl: Double
    var workoutMinutes: Int
    var workoutCount: Int
    var syncedAt: Date

    // MARK: Factory

    static func make(
        userId: String,
        date: Date = Date(),
        activeEnergyKcal: Double,
        stepsCount: Int,
        restingHeartRateBpm: Double,
        heartRateBpm: Double,
        waterMl: Double,
        workoutMinutes: Int,
        workoutCount: Int
    ) -> HealthSnapshot {
        let dateKey = DateFormatter.snapshotDate.string(from: date)
        return HealthSnapshot(
            id: "\(userId)_\(dateKey)",
            userId: userId,
            date: date,
            activeEnergyKcal: activeEnergyKcal,
            stepsCount: stepsCount,
            restingHeartRateBpm: restingHeartRateBpm,
            heartRateBpm: heartRateBpm,
            waterMl: waterMl,
            workoutMinutes: workoutMinutes,
            workoutCount: workoutCount,
            syncedAt: Date()
        )
    }
}

extension DateFormatter {
    static let snapshotDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
