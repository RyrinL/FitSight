import SwiftUI

struct CoachView: View {
    @ObservedObject var appVM: AppViewModel
    @ObservedObject var dashVM: DashboardViewModel

    @State private var showWeeklyPlan = false
    @State private var showMyPlan = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    if let profile = appVM.profile {
                        planSummaryCard(profile)
                    }

                    recoveryCard
                    HStack(spacing: 12) {
                        weeklyPlanButton
                        myPlanButton
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Your workouts", systemImage: "sparkles")
                            .font(.fitHeadline())
                            .padding(.horizontal, 4)

                        if dashVM.recommendations.isEmpty {
                            emptyState
                        } else {
                            ForEach(dashVM.recommendations) { rec in
                                WorkoutCard(recommendation: rec) {
                                    Task {
                                        guard let uid = appVM.currentUser?.uid else { return }
                                        await dashVM.logWorkout(rec, uid: uid)
                                        await appVM.markActiveAndSaveStreak(uid: uid)
                                    }
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
            .navigationTitle("Coach")
            .sheet(isPresented: $showWeeklyPlan) {
                WeeklyPlanView(dashVM: dashVM, appVM: appVM, initialTab: .generated)
            }
            .sheet(isPresented: $showMyPlan) {
                WeeklyPlanView(dashVM: dashVM, appVM: appVM, initialTab: .custom)
            }
            .task {
                dashVM.profile = appVM.profile
                if let uid = appVM.currentUser?.uid {
                    await dashVM.loadPlan(uid: uid)
                }
            }
        }
    }

    // MARK: - Plan summary

    private func planSummaryCard(_ profile: UserProfile) -> some View {
        HStack(spacing: 0) {
            planChip(icon: "target", label: profile.fitnessGoal.rawValue, gradient: FitGradient.mint)
            Spacer()
            planChip(icon: profile.experienceLevel == .beginner ? "figure.stand" : "dumbbell.fill",
                     label: profile.experienceLevel.rawValue, gradient: FitGradient.purple)
            Spacer()
            planChip(icon: "flame.fill", label: "\(Int(profile.computedActiveCalorieGoal)) kcal", gradient: FitGradient.energy)
        }
        .glassCard()
    }

    private func planChip(icon: String, label: String, gradient: LinearGradient) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(gradient)
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 80)
        }
    }

    // MARK: - Recovery card

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(Color.fitOrange)
                    .font(.title3)
                Text("How do you feel today?")
                    .font(.fitHeadline())
            }

            HStack(spacing: 8) {
                ForEach(RecoveryStatus.allCases) { status in
                    Button {
                        FitHaptic.impact(.light)
                        dashVM.recoveryStatus = status
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: status.symbolName)
                                .font(.system(size: 18, weight: .semibold))
                            Text(status.rawValue)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(dashVM.recoveryStatus == status
                            ? FitGradient.energy
                            : LinearGradient(colors: [Color(.tertiarySystemGroupedBackground)], startPoint: .top, endPoint: .bottom))
                        .foregroundStyle(dashVM.recoveryStatus == status ? .white : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .glassCard(tint: .fitOrange)
    }

    // MARK: - Plan navigation buttons

    private var weeklyPlanButton: some View {
        planNavCard(
            icon: "calendar",
            title: "Weekly Plan",
            subtitle: dashVM.weeklyPlan?.splitName ?? "Tap to generate",
            gradient: FitGradient.purple,
            shadow: .fitPurple
        ) {
            FitHaptic.impact(.light)
            if dashVM.weeklyPlan == nil, let profile = appVM.profile {
                dashVM.profile = profile
                Task {
                    guard let uid = appVM.currentUser?.uid else { return }
                    await dashVM.generateAndSavePlan(uid: uid)
                    showWeeklyPlan = true
                }
            } else {
                showWeeklyPlan = true
            }
        }
    }

    private var myPlanButton: some View {
        planNavCard(
            icon: dashVM.customPlan != nil ? "figure.strengthtraining.traditional" : "square.and.pencil",
            title: "My Plan",
            subtitle: dashVM.customPlan != nil ? "Your custom split" : "Build yours",
            gradient: FitGradient.mint,
            shadow: .mint
        ) {
            FitHaptic.impact(.light)
            showMyPlan = true
        }
    }

    /// Shared style so both plan cards are the same size and layout (symmetric).
    private func planNavCard(
        icon: String,
        title: String,
        subtitle: String,
        gradient: LinearGradient,
        shadow: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.22))
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer(minLength: 14)

                Text(title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 138, alignment: .leading)
            .padding(16)
            .background(gradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .fitShadow(color: shadow, radius: 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("No recommendations yet")
                .font(.fitHeadline())
                .foregroundStyle(.secondary)
            Text("Complete your profile to get personalised workouts.")
                .font(.subheadline)
                .foregroundStyle(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .glassCard()
    }
}
