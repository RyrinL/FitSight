import UserNotifications
import Foundation

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    // MARK: - Notification identifiers

    enum ID {
        static let workoutDaily  = "fitsight.workout.daily"
        static let mealBreakfast = "fitsight.meal.breakfast"
        static let mealLunch     = "fitsight.meal.lunch"
        static let mealDinner    = "fitsight.meal.dinner"
        static let goalEvening   = "fitsight.goal.evening"
        static let streakWarning = "fitsight.streak.warning"

        static let waterHours: [Int] = [9, 11, 13, 15, 17, 19]
        static var waterIDs: [String] { waterHours.map { "fitsight.water.\($0)" } }

        static var allIDs: [String] {
            [workoutDaily, mealBreakfast, mealLunch, mealDinner, goalEvening, streakWarning]
            + waterIDs
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized { return true }
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // Returns which of our known IDs currently have a pending request.
    func pendingIDs() async -> Set<String> {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return Set(requests.map(\.identifier)).intersection(Set(ID.allIDs))
    }

    // MARK: - Generic daily helper

    private func scheduleDaily(hour: Int, minute: Int = 0,
                                title: String, body: String, id: String) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])

        var components   = DateComponents()
        components.hour   = hour
        components.minute = minute

        let content       = UNMutableNotificationContent()
        content.title     = title
        content.body      = body
        content.sound     = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    // MARK: - Workout

    func scheduleWorkoutReminder(hour: Int = 8, minute: Int = 0) async {
        await scheduleDaily(
            hour: hour, minute: minute,
            title: "Time to train",
            body: "Your FitSight coach is ready. Let's hit today's goal.",
            id: ID.workoutDaily
        )
    }

    func cancelWorkoutReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [ID.workoutDaily])
    }

    // MARK: - Water

    func scheduleWaterReminders() async {
        for hour in ID.waterHours {
            await scheduleDaily(
                hour: hour, minute: 0,
                title: "Hydration check",
                body: "Keep sipping — your water goal won't hit itself.",
                id: "fitsight.water.\(hour)"
            )
        }
    }

    // Legacy alias used by older call sites.
    func scheduleWaterReminder() async { await scheduleWaterReminders() }

    func cancelWaterReminders() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ID.waterIDs)
    }

    // MARK: - Meals

    func scheduleMealReminders(breakfastHour: Int = 7,
                                lunchHour: Int    = 12,
                                dinnerHour: Int   = 18) async {
        await scheduleDaily(
            hour: breakfastHour, minute: 30,
            title: "Breakfast time",
            body: "Start your day strong — log your breakfast to hit your macros.",
            id: ID.mealBreakfast
        )
        await scheduleDaily(
            hour: lunchHour, minute: 0,
            title: "Lunch reminder",
            body: "Midday fuel check. Log your lunch and stay on track.",
            id: ID.mealLunch
        )
        await scheduleDaily(
            hour: dinnerHour, minute: 0,
            title: "Dinner time",
            body: "Log your dinner to see how close you are to today's goal.",
            id: ID.mealDinner
        )
    }

    func cancelMealReminders() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [ID.mealBreakfast, ID.mealLunch, ID.mealDinner])
    }

    // MARK: - Goal check-in

    /// Schedules an evening reminder personalised with the user's calorie goal.
    func scheduleGoalReminder(hour: Int = 20, minute: Int = 0, calorieGoal: Int = 0) async {
        let body = calorieGoal > 0
            ? "Check in on your \(calorieGoal) kcal goal and finish the day strong."
            : "Check in on today's goals before the day is over."
        await scheduleDaily(
            hour: hour, minute: minute,
            title: "Goal check-in",
            body: body,
            id: ID.goalEvening
        )
    }

    func cancelGoalReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [ID.goalEvening])
    }

    // MARK: - Streak warning

    func scheduleStreakWarning(currentStreak: Int) async {
        guard currentStreak > 0 else { return }
        await scheduleDaily(
            hour: 20, minute: 30,
            title: "Don't break your \(currentStreak)-day streak!",
            body: "Log a workout before midnight to keep it alive.",
            id: ID.streakWarning
        )
    }

    func cancelStreakWarning() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [ID.streakWarning])
    }

    // MARK: - Cancel all

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
