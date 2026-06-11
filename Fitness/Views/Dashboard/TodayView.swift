import SwiftUI

struct TodayView: View {
    @ObservedObject var appVM: AppViewModel
    @ObservedObject var dashVM: DashboardViewModel

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    ringHeroCard
                    HealthConnectionCard(healthKit: appVM.healthKit)
                    streakCard

                    if let rec = dashVM.recommendations.first {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Recommended now", systemImage: "sparkles")
                                .font(.fitHeadline())
                                .padding(.horizontal, 4)
                            WorkoutCard(recommendation: rec) {
                                Task {
                                    guard let uid = appVM.currentUser?.uid else { return }
                                    await dashVM.logWorkout(rec, uid: uid)
                                    await appVM.markActiveAndSaveStreak(uid: uid)
                                    await appVM.refreshAchievements(uid: uid, sessions: dashVM.workoutHistory)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("FitSight")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if let name = appVM.profile?.displayName, !name.isEmpty {
                        Text("Hi, \(name.components(separatedBy: " ").first ?? name)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        FitHaptic.impact(.light)
                        dashVM.onHealthKitRefresh()
                        Task { await appVM.healthKit.refreshAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.body.weight(.medium))
                    }
                    .accessibilityLabel("Refresh data")
                }
            }
            .task {
                guard let uid = appVM.currentUser?.uid else { return }
                dashVM.profile = appVM.profile
                dashVM.streak = appVM.streak
                await dashVM.loadData(uid: uid)
            }
            .onChange(of: appVM.healthKit.activeEnergyToday) { val in
                dashVM.activeEnergy = val
            }
        }
    }

    // MARK: - Ring hero card

    private var ringHeroCard: some View {
        VStack(spacing: 20) {
            HStack(alignment: .center, spacing: 24) {
                CalorieProgressRing(
                    calorieProgress: dashVM.activeEnergyProgress,
                    stepsProgress: min(Double(appVM.healthKit.stepsToday) / 10_000, 1),
                    workoutProgress: min(Double(dashVM.workoutHistory.count) / 3, 1),
                    centerLabel: "\(Int(dashVM.activeEnergy))",
                    size: 150
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Calorie ring \(Int(dashVM.activeEnergyProgress * 100))%, steps ring, workout ring")

                VStack(alignment: .leading, spacing: 14) {
                    ringLegendItem(color: .mint, label: "Active kcal",
                                   value: "\(Int(dashVM.activeEnergy))",
                                   total: "\(Int(dashVM.dailyCalorieGoal))")
                    ringLegendItem(color: .fitBlue, label: "Steps",
                                   value: "\(appVM.healthKit.stepsToday)",
                                   total: "10K")
                    ringLegendItem(color: .fitOrange, label: "Workouts",
                                   value: "\(dashVM.workoutHistory.count)",
                                   total: "3")
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                MetricTile(title: "Remaining", value: "\(Int(max(dashVM.remainingCalories, 0)))", unit: "kcal")
                MetricTile(title: "Resting HR", value: "\(Int(appVM.healthKit.restingHeartRate))", unit: "bpm", tint: .fitOrange)
            }
        }
        .glassCard(tint: .mint)
    }

    private func ringLegendItem(color: Color, label: String, value: String, total: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("\(value) / \(total)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
        }
    }

    // MARK: - Streak card

    private var streakCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(appVM.streak.currentStreak > 0 ? FitGradient.energy : LinearGradient(colors: [Color(.tertiarySystemGroupedBackground)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 48, height: 48)
                Image(systemName: "flame.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(appVM.streak.currentStreak > 0 ? .white : .secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("\(appVM.streak.currentStreak)-day streak")
                    .font(.fitHeadline())
                Text("Best: \(appVM.streak.longestStreak)  ·  Total: \(appVM.streak.totalActiveDays) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if appVM.streak.isActiveToday {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.mint)
            }
        }
        .glassCard(tint: appVM.streak.currentStreak > 0 ? .fitOrange : .white)
    }
}

// MARK: - Health connection card

private struct HealthConnectionCard: View {
    @ObservedObject var healthKit: HealthKitService

    var body: some View {
        if healthKit.authorizationState != .authorized {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.title2)
                        .foregroundStyle(Color.fitOrange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Health").font(.fitHeadline())
                        Text(healthKit.statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 10) {
                    Button { healthKit.requestAuthorization() } label: {
                        Label("Connect", systemImage: "heart")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(FitGradient.energy)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    Button { Task { await healthKit.refreshAll() } } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            .glassCard(tint: .fitOrange)
        }
    }
}
