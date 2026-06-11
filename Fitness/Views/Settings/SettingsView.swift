import SwiftUI
import UserNotifications

struct SettingsView: View {
    @ObservedObject var appVM: AppViewModel

    // Reminder toggles
    @State private var workoutEnabled  = false
    @State private var waterEnabled    = false
    @State private var mealsEnabled    = false
    @State private var goalEnabled     = false

    // Time pickers
    @State private var workoutHour  = 8
    @State private var goalHour     = 20

    // UI state
    @State private var showDeleteConfirm = false
    @State private var showProfileEdit   = false
    @State private var showCalorieGoal   = false
    @State private var notifDenied       = false

    private let ns = NotificationService.shared

    var body: some View {
        NavigationStack {
            List {
                if let profile = appVM.profile {
                    Section { profileHeader(profile) }
                }

                remindersSection
                healthSection
                aiSection
                profileSection
                aboutSection
                dangerSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showCalorieGoal) { CalorieGoalView(appVM: appVM) }
            .sheet(isPresented: $showProfileEdit) { ProfileSetupView(appVM: appVM) }
            .alert("Delete account?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    Task { try? await appVM.auth.deleteAccount() }
                    appVM.signOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All your data will be permanently removed from this device. This cannot be undone.")
            }
            .task { await restoreNotificationStates() }
        }
    }

    // MARK: - Reminders section

    private var remindersSection: some View {
        Section {
            if notifDenied {
                Label("Notifications are disabled in Settings.", systemImage: "bell.slash.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.fitOrange)
            }

            // Workout
            Toggle(isOn: $workoutEnabled) {
                Label("Daily workout reminder", systemImage: "figure.run")
            }
            .tint(.mint)
            .onChange(of: workoutEnabled) { enabled in
                Task { await handleWorkoutToggle(enabled) }
            }

            if workoutEnabled {
                timePicker(label: "Reminder time", selection: $workoutHour, range: 5..<22)
                    .onChange(of: workoutHour) { h in
                        Task { await ns.scheduleWorkoutReminder(hour: h) }
                    }
            }

            // Water
            Toggle(isOn: $waterEnabled) {
                Label("Hydration reminders", systemImage: "drop.fill")
            }
            .tint(Color.fitBlue)
            .onChange(of: waterEnabled) { enabled in
                Task {
                    if enabled { await authorize { await ns.scheduleWaterReminders() } }
                    else { ns.cancelWaterReminders() }
                }
            }

            // Meals
            Toggle(isOn: $mealsEnabled) {
                Label("Meal logging reminders", systemImage: "fork.knife")
            }
            .tint(Color.fitOrange)
            .onChange(of: mealsEnabled) { enabled in
                Task {
                    if enabled { await authorize { await ns.scheduleMealReminders() } }
                    else { ns.cancelMealReminders() }
                }
            }

            // Goal check-in
            Toggle(isOn: $goalEnabled) {
                Label("Evening goal check-in", systemImage: "target")
            }
            .tint(Color.fitPurple)
            .onChange(of: goalEnabled) { enabled in
                Task { await handleGoalToggle(enabled) }
            }

            if goalEnabled {
                timePicker(label: "Check-in time", selection: $goalHour, range: 17..<23)
                    .onChange(of: goalHour) { h in
                        Task {
                            let kcal = Int(appVM.profile?.recommendedDailyCalories ?? 0)
                            await ns.scheduleGoalReminder(hour: h, calorieGoal: kcal)
                        }
                    }
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text("Meal reminders fire at 7:30 AM, 12:00 PM, and 6:00 PM. Water reminders fire every two hours from 9 AM to 7 PM.")
                .font(.caption)
        }
    }

    // MARK: - Other sections

    private var healthSection: some View {
        Section("Apple Health") {
            HStack {
                Label("HealthKit status", systemImage: "heart.text.square.fill")
                Spacer()
                Text(appVM.healthKit.authorizationState == .authorized ? "Connected" : "Not connected")
                    .foregroundStyle(appVM.healthKit.authorizationState == .authorized ? Color.mint : Color.secondary)
                    .font(.subheadline)
            }
            Button("Re-authorize HealthKit") {
                appVM.healthKit.requestAuthorization()
            }
            .foregroundStyle(Color.mint)
        }
    }

    private var aiSection: some View {
        Section("AI Coach") {
            HStack {
                Label("Groq AI", systemImage: "cpu")
                Spacer()
                Text(Secrets.groqKey.isEmpty ? "Not set" : "Configured")
                    .foregroundStyle(Secrets.groqKey.isEmpty ? Color.secondary : Color.mint)
                    .font(.subheadline)
            }
            FeatureRow(
                title: "Powered by Groq",
                subtitle: "Running Llama 3.1 via Groq (free). Get a key at console.groq.com/keys.",
                symbolName: "key.fill"
            )
        }
    }

    private var profileSection: some View {
        Section("Profile") {
            Button { showCalorieGoal = true } label: {
                HStack {
                    Label("Calorie goal", systemImage: "flame.circle.fill")
                    Spacer()
                    if let p = appVM.profile {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(p.recommendedDailyCalories)) kcal/day")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.mint)
                            Text("\(p.fitnessGoal.rawValue)  ·  \(p.fitnessGoal.adjustmentLabel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .foregroundStyle(.primary)

            Button { showProfileEdit = true } label: {
                Label("Edit profile & metrics", systemImage: "person.crop.circle")
            }
            .foregroundStyle(Color.mint)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text("1.0.0").foregroundStyle(.secondary).font(.subheadline)
            }
            FeatureRow(
                title: "Privacy policy",
                subtitle: "FitSight processes all pose analysis on-device. Health data stays on your iPhone.",
                symbolName: "lock.shield"
            )
            FeatureRow(
                title: "Medical disclaimer",
                subtitle: "FitSight provides fitness coaching guidance only, not medical advice or diagnosis.",
                symbolName: "cross.case"
            )
        }
    }

    private var dangerSection: some View {
        Section {
            Button("Sign out") {
                FitHaptic.warning()
                appVM.signOut()
            }
            .foregroundStyle(Color.fitRed)

            Button("Delete account", role: .destructive) {
                showDeleteConfirm = true
            }
        }
    }

    // MARK: - Helpers

    private func timePicker(label: String, selection: Binding<Int>, range: Range<Int>) -> some View {
        Picker(label, selection: selection) {
            ForEach(Array(range), id: \.self) { h in
                Text(hourLabel(h)).tag(h)
            }
        }
    }

    private func handleWorkoutToggle(_ enabled: Bool) async {
        if enabled {
            await authorize { await ns.scheduleWorkoutReminder(hour: workoutHour) }
        } else {
            ns.cancelWorkoutReminder()
        }
    }

    private func handleGoalToggle(_ enabled: Bool) async {
        if enabled {
            let kcal = Int(appVM.profile?.recommendedDailyCalories ?? 0)
            await authorize { await ns.scheduleGoalReminder(hour: goalHour, calorieGoal: kcal) }
        } else {
            ns.cancelGoalReminder()
        }
    }

    // Requests permission then runs the schedule block; rolls back the toggle on denial.
    private func authorize(_ schedule: () async -> Void) async {
        let granted = await ns.requestAuthorization()
        if granted {
            notifDenied = false
            await schedule()
        } else {
            notifDenied = true
            // Roll back all toggles that might have just been set
            workoutEnabled = false
            waterEnabled   = false
            mealsEnabled   = false
            goalEnabled    = false
        }
    }

    // Read pending notifications and restore toggle/picker state without firing onChange.
    @MainActor
    private func restoreNotificationStates() async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let ids = Set(pending.map(\.identifier))

        workoutEnabled = ids.contains(NotificationService.ID.workoutDaily)
        waterEnabled   = ids.contains("fitsight.water.9")
        mealsEnabled   = ids.contains(NotificationService.ID.mealBreakfast)
        goalEnabled    = ids.contains(NotificationService.ID.goalEvening)

        // Restore saved workout hour from the trigger if available
        if let req = pending.first(where: { $0.identifier == NotificationService.ID.workoutDaily }),
           let trigger = req.trigger as? UNCalendarNotificationTrigger,
           let hour = trigger.dateComponents.hour {
            workoutHour = hour
        }

        // Restore goal hour
        if let req = pending.first(where: { $0.identifier == NotificationService.ID.goalEvening }),
           let trigger = req.trigger as? UNCalendarNotificationTrigger,
           let hour = trigger.dateComponents.hour {
            goalHour = hour
        }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notifDenied = settings.authorizationStatus == .denied
    }

    private func profileHeader(_ profile: UserProfile) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(FitGradient.mint)
                    .frame(width: 56, height: 56)
                Text(profile.displayName.prefix(1).uppercased())
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.displayName).font(.headline)
                Text(profile.email).font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Text(profile.fitnessGoal.rawValue)
                    Text("·")
                    Text(profile.activityLevel.rawValue)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func hourLabel(_ h: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var comps = DateComponents(); comps.hour = h; comps.minute = 0
        return Calendar.current.date(from: comps).map { formatter.string(from: $0) } ?? "\(h):00"
    }
}
