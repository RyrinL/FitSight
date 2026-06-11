import SwiftUI

enum PlanSource: String, CaseIterable {
    case generated = "AI Plan"
    case custom    = "My Plan"
}

struct WeeklyPlanView: View {
    @ObservedObject var dashVM: DashboardViewModel
    @ObservedObject var appVM: AppViewModel
    @Environment(\.dismiss) private var dismiss

    private let initialTab: PlanSource

    @State private var planSource: PlanSource
    @State private var selectedDayId: String? = nil
    @State private var isRegenerating = false
    @State private var showingCustomBuilder = false

    init(dashVM: DashboardViewModel, appVM: AppViewModel, initialTab: PlanSource = .generated) {
        self.dashVM = dashVM
        self.appVM = appVM
        self.initialTab = initialTab
        _planSource = State(initialValue: initialTab)
    }

    private var activePlan: WorkoutPlan? {
        planSource == .generated ? dashVM.weeklyPlan : dashVM.customPlan
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Source picker
                Picker("Plan", selection: $planSource) {
                    ForEach(PlanSource.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                Group {
                    if let plan = activePlan {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 20) {
                                planHeaderCard(plan)
                                dayList(plan)
                                if planSource == .generated {
                                    regenerateButton(plan)
                                } else {
                                    editCustomButton
                                }
                                Spacer(minLength: 20)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 32)
                        }
                    } else {
                        planSource == .generated ? AnyView(emptyState) : AnyView(customEmptyState)
                    }
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Weekly Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if planSource == .custom {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            FitHaptic.impact(.light)
                            showingCustomBuilder = true
                        } label: {
                            Image(systemName: dashVM.customPlan == nil ? "plus" : "pencil")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCustomBuilder) {
                CustomPlanBuilderView(existingPlan: dashVM.customPlan) { plan in
                    guard let uid = appVM.currentUser?.uid else { return }
                    Task { await dashVM.saveCustomPlan(plan, uid: uid) }
                }
            }
        }
    }

    // MARK: - Plan header

    private func planHeaderCard(_ plan: WorkoutPlan) -> some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.splitName)
                        .font(.fitHeadline())
                    Text("\(plan.goal.rawValue)  ·  \(plan.experience.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(plan.weeklyVolume)")
                        .font(.fitMono(22))
                        .foregroundStyle(Color.fitPurple)
                    Text("total sets")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                let trainingDays = plan.days.filter { $0.sessionType != .rest }
                PlanStatChip(label: "\(trainingDays.count) days", icon: "calendar", color: .fitPurple)
                PlanStatChip(label: "\(trainingDays.reduce(0) { $0 + $1.estimatedMinutes }) min", icon: "clock", color: .mint)
                PlanStatChip(label: "\(trainingDays.reduce(0) { $0 + $1.estimatedCalories }) kcal", icon: "flame.fill", color: .fitOrange)
            }

            // Equipment chips
            let eq = Array(Set(plan.equipment)).sorted { $0.rawValue < $1.rawValue }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(eq) { item in
                        Label(item.rawValue, systemImage: item.symbolName)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .glassCard(tint: .fitPurple)
    }

    // MARK: - Day list

    private func dayList(_ plan: WorkoutPlan) -> some View {
        VStack(spacing: 12) {
            ForEach(plan.days) { day in
                DayCard(
                    day: day,
                    isSelected: selectedDayId == day.id,
                    onTap: {
                        FitHaptic.impact(.light)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            selectedDayId = selectedDayId == day.id ? nil : day.id
                        }
                    },
                    onLog: {
                        guard let uid = appVM.currentUser?.uid else { return }
                        Task {
                            await dashVM.logWorkout(day, uid: uid)
                            await appVM.markActiveAndSaveStreak(uid: uid)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Regenerate

    private func regenerateButton(_ plan: WorkoutPlan) -> some View {
        Button {
            guard !isRegenerating else { return }
            FitHaptic.impact(.medium)
            isRegenerating = true
            Task {
                guard let uid = appVM.currentUser?.uid else { isRegenerating = false; return }
                dashVM.profile = appVM.profile
                await dashVM.generateAndSavePlan(uid: uid)
                selectedDayId = nil
                isRegenerating = false
                FitHaptic.success()
            }
        } label: {
            HStack {
                if isRegenerating {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
                Text(isRegenerating ? "Generating…" : "Regenerate Plan")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.tertiarySystemGroupedBackground))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isRegenerating)
    }

    // MARK: - Edit custom button

    private var editCustomButton: some View {
        Button {
            FitHaptic.impact(.medium)
            showingCustomBuilder = true
        } label: {
            HStack {
                Image(systemName: "pencil")
                Text("Edit My Plan")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.tertiarySystemGroupedBackground))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty states

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("No plan generated yet")
                .font(.fitHeadline())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var customEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 52))
                .foregroundStyle(Color.fitPurple.opacity(0.6))
            VStack(spacing: 6) {
                Text("Build Your Own Plan")
                    .font(.fitHeadline())
                Text("Set your own exercises, sets, and reps\nfor each day of the week.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                FitHaptic.impact(.medium)
                showingCustomBuilder = true
            } label: {
                Label("Create My Plan", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 13)
                    .background(FitGradient.purple)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Day card

private struct DayCard: View {
    let day: WorkoutDay
    let isSelected: Bool
    let onTap: () -> Void
    var onLog: (() -> Void)? = nil

    @State private var isLogging = false

    var isRest: Bool { day.sessionType == .rest }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isRest ? LinearGradient(colors: [Color(.tertiarySystemGroupedBackground)],
                                                      startPoint: .top, endPoint: .bottom) : FitGradient.purple)
                        .frame(width: 42, height: 42)
                    Image(systemName: day.sessionType.symbolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isRest ? Color.secondary : Color.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(day.weekdayName)
                        .font(.fitHeadline())
                    Text(day.sessionType.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !isRest {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(day.estimatedMinutes) min")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.mint)
                        Text("\(day.estimatedCalories) kcal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(5)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Circle())
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            // Expandable exercise list
            if isSelected && !day.exercises.isEmpty {
                Divider().padding(.vertical, 12)

                VStack(spacing: 8) {
                    ForEach(day.exercises) { exercise in
                        ExerciseRow(exercise: exercise)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }

                if let onLog {
                    Button {
                        FitHaptic.success()
                        isLogging = true
                        onLog()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { isLogging = false }
                    } label: {
                        HStack {
                            Image(systemName: isLogging ? "checkmark.circle.fill" : "plus.circle.fill")
                            Text(isLogging ? "Logged!" : "Log this workout")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background { isLogging ? AnyView(Color.mint.opacity(0.15)) : AnyView(FitGradient.mint) }
                        .foregroundStyle(isLogging ? Color.mint : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isLogging)
                    .padding(.top, 12)
                }
            }

            // Rest day note
            if isRest && !day.notes.isEmpty {
                Text(day.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
        .glassCard(tint: isRest ? .clear : .fitPurple)
    }
}

// MARK: - Stat chip

private struct PlanStatChip: View {
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(Capsule())
    }
}
