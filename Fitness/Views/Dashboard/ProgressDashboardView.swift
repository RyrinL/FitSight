import SwiftUI
import Charts

struct ProgressDashboardView: View {
    @ObservedObject var appVM: AppViewModel
    @ObservedObject var dashVM: DashboardViewModel

    @State private var selectedCategory: AchievementCategory = .all

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    streakCard
                    achievementsSection
                    weeklyChartCard
                    workoutHistorySection
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Progress")
            .task {
                guard let uid = appVM.currentUser?.uid else { return }
                dashVM.profile = appVM.profile
                dashVM.streak  = appVM.streak
                await dashVM.loadData(uid: uid)
                await appVM.refreshAchievements(uid: uid, sessions: dashVM.workoutHistory)
            }
        }
    }

    // MARK: - Streak card

    private var streakCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                // Flame + streak number
                VStack(spacing: 4) {
                    Image(systemName: appVM.streak.currentStreak > 0 ? "flame.fill" : "flame")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(
                            appVM.streak.currentStreak > 0
                                ? AnyShapeStyle(FitGradient.energy)
                                : AnyShapeStyle(Color.secondary)
                        )
                    Text("\(appVM.streak.currentStreak)")
                        .font(.fitMono(34))
                        .foregroundStyle(
                            appVM.streak.currentStreak > 0 ? Color.fitOrange : Color.secondary
                        )
                    Text("day streak")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Divider().frame(height: 80)

                VStack(alignment: .leading, spacing: 10) {
                    streakStat(icon: "chart.line.uptrend.xyaxis",
                               label: "Best  \(appVM.streak.longestStreak) days")
                    streakStat(icon: "calendar",
                               label: "\(appVM.streak.totalActiveDays) total active days")
                    weekDots
                }
            }
        }
        .glassCard(tint: appVM.streak.currentStreak > 0 ? Color.fitOrange : Color.white)
    }

    private func streakStat(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
            Text(label)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var weekDots: some View {
        let cal       = Calendar.current
        let today     = Date()
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        let days      = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
        let letters   = ["M", "T", "W", "T", "F", "S", "S"]

        return HStack(spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { i, day in
                let isToday  = cal.isDateInToday(day)
                let isActive = dashVM.workoutHistory.contains { cal.isDate($0.date, inSameDayAs: day) }
                VStack(spacing: 3) {
                    Text(letters[i])
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(isToday ? Color.fitOrange : Color.secondary)
                    Circle()
                        .fill(isActive
                              ? Color.fitOrange
                              : (isToday ? Color.fitOrange.opacity(0.35) : Color.secondary.opacity(0.15)))
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(isToday ? Color.fitOrange : Color.clear, lineWidth: 1.5)
                        )
                }
            }
        }
    }

    // MARK: - Achievements section

    private var filteredAchievements: [Achievement] {
        selectedCategory == .all
            ? appVM.achievements
            : appVM.achievements.filter { $0.category == selectedCategory }
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Group {
                HStack {
                    Text("Achievements")
                        .font(.fitHeadline())
                    Spacer()
                    let earned = appVM.achievements.filter(\.isEarned).count
                    Text("\(earned) / \(appVM.achievements.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                categoryFilter
            }

            if filteredAchievements.isEmpty {
                Text("No achievements in this category yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                AchievementGrid(achievements: filteredAchievements)
            }
        }
        .glassCard(tint: Color.fitGold)
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AchievementCategory.allCases) { cat in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedCategory = cat
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: cat.symbolName)
                                .font(.system(size: 10, weight: .semibold))
                            Text(cat.rawValue)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selectedCategory == cat
                                ? Color.fitGold.opacity(0.2)
                                : Color.secondary.opacity(0.08)
                        )
                        .foregroundStyle(
                            selectedCategory == cat ? Color.fitGold : Color.secondary
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(
                                    selectedCategory == cat
                                        ? Color.fitGold.opacity(0.5)
                                        : Color.clear,
                                    lineWidth: 1
                                )
                        )
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Weekly chart card

    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly active energy")
                        .font(.fitHeadline())
                    let total = dashVM.weeklyMetrics.reduce(0) { $0 + $1.value }
                    Text("\(Int(total)) kcal this week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(Color.mint)
                    .font(.title3)
            }

            Chart(dashVM.weeklyMetrics) { metric in
                BarMark(
                    x: .value("Day", metric.day),
                    y: .value("kcal", metric.value)
                )
                .foregroundStyle(FitGradient.mint)
                .cornerRadius(6)
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(.secondary.opacity(0.3))
                    AxisValueLabel()
                        .font(.system(size: 10, design: .rounded))
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
            }
            .frame(height: 160)
            .accessibilityLabel("Weekly active energy bar chart")
        }
        .glassCard(tint: .mint)
    }

    // MARK: - Workout history section

    private var workoutHistorySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recent workouts")
                    .font(.fitHeadline())
                Spacer()
                Text("\(dashVM.workoutHistory.count) total")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 14)

            if dashVM.workoutHistory.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "figure.run.circle")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary.opacity(0.4))
                    Text("No workouts logged yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Start a session from the Coach tab.")
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(dashVM.workoutHistory.prefix(8).enumerated()), id: \.element.id) { i, session in
                        if i > 0 { Divider().padding(.vertical, 10) }
                        WorkoutHistoryRow(session: session)
                    }
                }
            }
        }
        .glassCard()
    }
}

// MARK: - Workout history row

private struct WorkoutHistoryRow: View {
    let session: WorkoutSession

    private var dateString: String {
        let f = DateFormatter()
        f.dateStyle = .medium; f.timeStyle = .none
        return f.string(from: session.date)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(FitGradient.mint)
                    .frame(width: 38, height: 38)
                Image(systemName: session.exerciseType.isEmpty ? "figure.run" : session.exerciseType)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(session.title)
                    .font(.subheadline.weight(.semibold))
                Text("\(session.durationMinutes) min  ·  \(session.caloriesBurned) kcal  ·  \(dateString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let score = session.formScore {
                VStack(spacing: 1) {
                    Text("\(score)%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.mint)
                    Text("form")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
