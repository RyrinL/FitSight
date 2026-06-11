import SwiftUI

// MARK: - CalorieGoalView
// Interactive Mifflin-St Jeor calculator.
// Rings update live as the user adjusts any input slider or picker.
// Tapping "Save goal" persists the full UserProfile to the database
// (LocalDatabaseService today; swap for FirestoreService when Firebase is added).

struct CalorieGoalView: View {
    @ObservedObject var appVM: AppViewModel
    @Environment(\.dismiss) private var dismiss

    // Inputs — seeded from existing profile on appear
    @State private var displayName: String = ""
    @State private var age: Double = 28
    @State private var weightKg: Double = 70
    @State private var heightCm: Double = 170
    @State private var sex: BiologicalSex = .male
    @State private var activityLevel: ActivityLevel = .moderatelyActive
    @State private var goal: FitnessGoal = .fatLoss
    @State private var focus: WorkoutFocus = .balanced
    @State private var workoutMinutes: Double = 30

    @State private var isSaving = false
    @State private var savedPulse = false

    // MARK: Computed results (live)

    private var bmr: Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * age
        switch sex {
        case .male:   return base + 5
        case .female: return base - 161
        case .other:  return base - 78
        }
    }

    private var tdee: Double { bmr * activityLevel.multiplier }

    private var recommended: Double {
        let minIntake: Double
        switch sex {
        case .female: minIntake = 1_200
        case .male:   minIntake = 1_500
        case .other:  minIntake = 1_350
        }
        return max(tdee + goal.calorieAdjustment, minIntake)
    }

    private var activeCalorieGoal: Double {
        max(tdee * goal.activeCalorieFraction, goal.activeCalorieFloor)
    }

    private var macros: MacroTargets {
        MacroTargets.compute(calories: recommended, goal: goal)
    }

    // Ring fractions
    private var calorieFrac: Double { min(recommended / max(tdee, 1), 1.2) / 1.2 }
    private var bmrFrac:     Double { min(bmr  / max(tdee, 1), 1) }
    private var activeFrac:  Double { min(activeCalorieGoal / max(tdee, 1), 1) }

    private var adjustmentColor: Color {
        switch goal {
        case .fatLoss:     return .fitOrange
        case .maintenance: return .mint
        case .strength:    return .fitBlue
        case .endurance:   return .fitPurple
        }
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    heroSection
                    statRow
                    adjustmentBadge
                    macroCard
                    inputsCard
                    saveButton
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Calorie Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { seedFromProfile() }
        }
    }

    // MARK: - Hero ring section

    private var heroSection: some View {
        VStack(spacing: 16) {
            CalorieProgressRing(
                calorieProgress: calorieFrac,
                stepsProgress: bmrFrac,
                workoutProgress: activeFrac,
                centerLabel: "\(Int(recommended))",
                size: 210
            )
            .padding(.top, 8)

            // Ring legend (custom — different meaning from TodayView)
            HStack(spacing: 24) {
                ringLegendItem(.mint,      "Recommended", "\(Int(recommended)) kcal")
                ringLegendItem(.fitBlue,   "BMR",         "\(Int(bmr)) kcal")
                ringLegendItem(.fitOrange, "Active",      "\(Int(activeCalorieGoal)) kcal")
            }
        }
        .glassCard(tint: .mint)
    }

    private func ringLegendItem(_ color: Color, _ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(value)
                .font(.fitMono(12))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Stat row

    private var statRow: some View {
        HStack(spacing: 12) {
            CalorieStatTile(label: "BMR",        value: Int(bmr),         unit: "kcal",     gradient: FitGradient.purple)
            CalorieStatTile(label: "TDEE",       value: Int(tdee),        unit: "kcal",     gradient: FitGradient.steps)
            CalorieStatTile(label: "Daily goal", value: Int(recommended), unit: "kcal/day", gradient: goalGradient)
        }
    }

    private var goalGradient: LinearGradient {
        switch goal {
        case .fatLoss:     return FitGradient.energy
        case .maintenance: return FitGradient.mint
        case .strength:    return FitGradient.steps
        case .endurance:   return FitGradient.purple
        }
    }

    // MARK: - Adjustment badge

    private var adjustmentBadge: some View {
        let adj = Int(goal.calorieAdjustment)
        let clamped = Int(recommended - tdee)
        let isFloored = clamped != adj
        let label: String = isFloored
            ? "Minimum safe intake applied (\(Int(recommended)) kcal)"
            : (adj == 0 ? "Maintenance — eating at TDEE" : (adj > 0 ? "+\(adj) kcal/day surplus" : "\(adj) kcal/day deficit"))

        return HStack(spacing: 10) {
            Image(systemName: adj < 0 ? "arrow.down.circle.fill" : (adj == 0 ? "equal.circle.fill" : "arrow.up.circle.fill"))
                .font(.title3)
                .foregroundStyle(adjustmentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .contentTransition(.opacity)
                if !isFloored && adj != 0 {
                    let weeks = abs(adj) == 500 ? "≈ 0.5 kg/week" : (abs(adj) == 300 ? "lean bulk pace" : "")
                    if !weeks.isEmpty {
                        Text(weeks).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(adjustmentColor.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(adjustmentColor.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: goal)
    }

    // MARK: - Macro card

    private var macroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Macronutrient targets")
                    .font(.fitHeadline())
                Spacer()
                Text("at \(Int(recommended)) kcal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            VStack(spacing: 14) {
                MacroBar(label: "Protein",
                         grams: macros.proteinG,
                         kcal: macros.proteinKcal,
                         fraction: macros.proteinFraction,
                         color: .fitBlue,
                         note: "2 kcal/g × 4")

                MacroBar(label: "Carbohydrates",
                         grams: macros.carbsG,
                         kcal: macros.carbsKcal,
                         fraction: macros.carbsFraction,
                         color: .fitOrange,
                         note: "4 kcal/g")

                MacroBar(label: "Fat",
                         grams: macros.fatG,
                         kcal: macros.fatKcal,
                         fraction: macros.fatFraction,
                         color: .fitPurple,
                         note: "9 kcal/g")
            }

            Text("Ratios adjust automatically per goal (fat loss = high protein, endurance = high carb).")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.8))
        }
        .glassCard()
    }

    private var goalPicker: some View {
        Picker("", selection: $goal) {
            ForEach(FitnessGoal.allCases, id: \.rawValue) { g in
                Text(g.rawValue).tag(g)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Inputs card

    private var inputsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Inputs")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.bottom, 16)

            VStack(spacing: 0) {
                Group {
                    // Sex
                    GoalPickerRow(label: "Biological sex", systemImage: "person.fill") {
                        Picker("", selection: $sex) {
                            ForEach(BiologicalSex.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    GoalDivider()
                    // Age
                    GoalSliderRow(label: "Age", value: $age,
                                  range: 14...80, step: 1,
                                  format: "%.0f yrs", systemImage: "calendar")
                    GoalDivider()
                    // Weight
                    GoalSliderRow(label: "Weight", value: $weightKg,
                                  range: 30...200, step: 0.5,
                                  format: "%.1f kg", systemImage: "scalemass")
                    GoalDivider()
                }
                Group {
                    // Height
                    GoalSliderRow(label: "Height", value: $heightCm,
                                  range: 120...220, step: 1,
                                  format: "%.0f cm", systemImage: "ruler")
                    GoalDivider()
                    // Activity level
                    GoalPickerRow(label: "Activity level", systemImage: "figure.walk") {
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("", selection: $activityLevel) {
                                ForEach(ActivityLevel.allCases) { Text($0.rawValue).tag($0) }
                            }
                            Text(activityLevel.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .animation(.easeInOut, value: activityLevel)
                        }
                    }
                    GoalDivider()
                    // Goal
                    GoalPickerRow(label: "Goal", systemImage: "target") {
                        goalPicker
                    }
                }
            }
        }
        .glassCard()
    }

    // MARK: - Save button

    private var saveButton: some View {
        Button {
            FitHaptic.impact(.medium)
            Task { await save() }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(savedPulse ? AnyShapeStyle(Color.mint.opacity(0.2)) : AnyShapeStyle(goalGradient))
                    .fitShadow(color: .mint, radius: 12)
                if isSaving {
                    ProgressView().tint(.white)
                } else if savedPulse {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Saved!").fontWeight(.bold)
                    }
                    .foregroundStyle(.mint)
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("Save goal").fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .disabled(isSaving)
        .animation(.easeInOut(duration: 0.2), value: savedPulse)
    }

    // MARK: - Logic

    private func seedFromProfile() {
        guard let p = appVM.profile else { return }
        displayName    = p.displayName
        age            = Double(p.age)
        weightKg       = p.weightKg
        heightCm       = p.heightCm
        sex            = p.sex
        activityLevel  = p.activityLevel
        goal           = p.fitnessGoal
        focus          = p.workoutFocus
        workoutMinutes = Double(p.workoutMinutes)
    }

    private func save() async {
        guard let uid = appVM.currentUser?.uid else { return }
        isSaving = true
        let profile = UserProfile(
            id: uid,
            email: appVM.currentUser?.email ?? "",
            displayName: displayName.isEmpty ? (appVM.profile?.displayName ?? "You") : displayName,
            age: Int(age),
            weightKg: weightKg,
            heightCm: heightCm,
            sex: sex,
            activityLevel: activityLevel,
            fitnessGoal: goal,
            workoutFocus: focus,
            workoutMinutes: Int(workoutMinutes),
            joinedDate: appVM.profile?.joinedDate ?? Date(),
            experienceLevel: appVM.profile?.experienceLevel ?? .beginner,
            availableEquipment: appVM.profile?.availableEquipment ?? [.bodyweight]
        )
        // Persists to LocalDatabaseService (UserDefaults).
        // When Firebase SDK is added, swap LocalDatabaseService.saveUserProfile for:
        //   db.collection("users").document(uid)
        //     .setData(profile.firestoreData, merge: true)
        await appVM.saveProfile(profile)
        isSaving = false
        FitHaptic.success()
        savedPulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            savedPulse = false
            dismiss()
        }
    }
}

// MARK: - Sub-components

private struct CalorieStatTile: View {
    let label: String
    let value: Int
    let unit: String
    let gradient: LinearGradient

    var body: some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.fitMono(22))
                .monospacedDigit()
                .contentTransition(.numericText())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(unit)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .background(gradient.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct MacroBar: View {
    let label: String
    let grams: Double
    let kcal: Double
    let fraction: Double
    let color: Color
    let note: String

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: 4, height: 18)
                    Text(label)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(grams))g")
                        .font(.fitMono(14))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("\(Int(kcal)) kcal  ·  \(note)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.12))
                        .frame(height: 7)
                    Capsule()
                        .fill(color)
                        .frame(width: appeared ? geo.size.width * min(fraction, 1) : 0, height: 7)
                        .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.15), value: appeared)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: fraction)
                }
            }
            .frame(height: 7)
        }
        .onAppear { appeared = true }
    }
}

private struct GoalPickerRow<Content: View>: View {
    let label: String
    let systemImage: String
    let content: () -> Content

    init(label: String, systemImage: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.systemImage = systemImage
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(label, systemImage: systemImage)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(.secondary)
            content()
        }
        .padding(.vertical, 12)
    }
}

private struct GoalSliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(label, systemImage: systemImage)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: format, value))
                    .font(.fitMono(14))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Slider(value: $value, in: range, step: step)
                .tint(.mint)
        }
        .padding(.vertical, 12)
    }
}

private struct GoalDivider: View {
    var body: some View {
        Divider().padding(.vertical, 4)
    }
}
