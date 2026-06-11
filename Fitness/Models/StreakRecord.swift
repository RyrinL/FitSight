import Foundation

// MARK: - Streak tracking

struct StreakRecord: Codable {
    var userId: String
    var currentStreak: Int
    var longestStreak: Int
    var lastActiveDate: Date?
    var totalActiveDays: Int

    mutating func markActiveToday() {
        let today = Calendar.current.startOfDay(for: Date())
        if let last = lastActiveDate {
            let lastDay = Calendar.current.startOfDay(for: last)
            let diff = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if diff == 1 {
                currentStreak += 1
            } else if diff > 1 {
                currentStreak = 1
            }
            // diff == 0 means already marked today — no change
        } else {
            currentStreak = 1
        }
        longestStreak = max(longestStreak, currentStreak)
        if lastActiveDate.map({ !Calendar.current.isDateInToday($0) }) ?? true {
            totalActiveDays += 1
        }
        lastActiveDate = Date()
    }

    var isActiveToday: Bool {
        guard let last = lastActiveDate else { return false }
        return Calendar.current.isDateInToday(last)
    }

    static func empty(userId: String) -> StreakRecord {
        StreakRecord(userId: userId, currentStreak: 0, longestStreak: 0,
                     lastActiveDate: nil, totalActiveDays: 0)
    }
}

// MARK: - Achievement

struct Achievement: Codable, Identifiable {
    let id: String
    let category: AchievementCategory
    let title: String
    let description: String
    let symbolName: String
    let tier: AchievementTier
    var earnedDate: Date?
    var currentValue: Int
    let targetValue: Int

    var isEarned: Bool { earnedDate != nil }

    var progress: Double {
        guard targetValue > 0 else { return isEarned ? 1 : 0 }
        return min(Double(currentValue) / Double(targetValue), 1.0)
    }
}

// MARK: - Achievement category

enum AchievementCategory: String, Codable, CaseIterable, Identifiable {
    case all       = "All"
    case streak    = "Streak"
    case workout   = "Workout"
    case calories  = "Calories"
    case form      = "Form"
    case nutrition = "Nutrition"
    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .all:       return "square.grid.2x2.fill"
        case .streak:    return "flame.fill"
        case .workout:   return "figure.run"
        case .calories:  return "bolt.fill"
        case .form:      return "camera.fill"
        case .nutrition: return "fork.knife"
        }
    }
}

// MARK: - Achievement tier

enum AchievementTier: String, Codable {
    case bronze, silver, gold
}
