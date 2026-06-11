import SwiftUI

struct ProfileSetupView: View {
    @ObservedObject var appVM: AppViewModel

    @State private var displayName      = ""
    @State private var age: Double      = 28
    @State private var weightKg: Double = 70
    @State private var heightCm: Double = 170
    @State private var sex: BiologicalSex            = .male
    @State private var activityLevel: ActivityLevel  = .moderatelyActive
    @State private var goal: FitnessGoal             = .fatLoss
    @State private var focus: WorkoutFocus           = .balanced
    @State private var workoutMinutes: Double        = 30
    @State private var experienceLevel: ExperienceLevel  = .beginner
    @State private var availableEquipment: Set<Equipment> = [.bodyweight]
    @State private var isSaving = false

    private var previewProfile: UserProfile {
        UserProfile(
            id: "", email: "", displayName: "",
            age: Int(age), weightKg: weightKg, heightCm: heightCm,
            sex: sex, activityLevel: activityLevel,
            fitnessGoal: goal, workoutFocus: focus,
            workoutMinutes: Int(workoutMinutes), joinedDate: Date(),
            experienceLevel: experienceLevel,
            availableEquipment: Array(availableEquipment)
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("About you") {
                    TextField("Display name", text: $displayName)

                    Picker("Sex", selection: $sex) {
                        ForEach(BiologicalSex.allCases) { Text($0.rawValue).tag($0) }
                    }

                    NumericField(label: "Age",    unit: "yrs", value: $age,
                                 step: 1, range: 14...80, fractionDigits: 0)
                    NumericField(label: "Weight", unit: "kg",  value: $weightKg,
                                 step: 0.5, range: 30...300, fractionDigits: 1)
                    NumericField(label: "Height", unit: "cm",  value: $heightCm,
                                 step: 0.5, range: 100...250, fractionDigits: 1)
                }

                Section("Activity & Goal") {
                    Picker("Activity level", selection: $activityLevel) {
                        ForEach(ActivityLevel.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Goal", selection: $goal) {
                        ForEach(FitnessGoal.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Workout focus", selection: $focus) {
                        ForEach(WorkoutFocus.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Experience", selection: $experienceLevel) {
                        ForEach(ExperienceLevel.allCases) { Text($0.rawValue).tag($0) }
                    }
                    NumericField(label: "Daily workout time", unit: "min", value: $workoutMinutes,
                                 step: 5, range: 10...180, fractionDigits: 0)
                }

                Section("Available equipment") {
                    ForEach(Equipment.allCases) { item in
                        HStack {
                            Image(systemName: item.symbolName)
                                .foregroundStyle(Color.mint)
                                .frame(width: 24)
                            Text(item.rawValue)
                            Spacer()
                            if availableEquipment.contains(item) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.mint)
                                    .fontWeight(.semibold)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard item != .bodyweight else { return }
                            if availableEquipment.contains(item) {
                                availableEquipment.remove(item)
                            } else {
                                availableEquipment.insert(item)
                            }
                        }
                    }
                    Text("Bodyweight is always included.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Estimated targets") {
                    calcRow("BMR",  value: previewProfile.bmr)
                    calcRow("TDEE", value: previewProfile.tdee)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recommended daily calories")
                            Text(goal.adjustmentLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(previewProfile.recommendedDailyCalories)) kcal")
                            .foregroundStyle(Color.mint)
                            .fontWeight(.semibold)
                    }
                    Text("Fine-tune in Settings → Calorie Goal for a live calculator with macro breakdown.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Save & start").fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSaving || displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Set up your profile")
            .onAppear {
                guard let p = appVM.profile else { return }
                displayName        = p.displayName
                age                = Double(p.age)
                weightKg           = p.weightKg
                heightCm           = p.heightCm
                sex                = p.sex
                activityLevel      = p.activityLevel
                goal               = p.fitnessGoal
                focus              = p.workoutFocus
                workoutMinutes     = Double(p.workoutMinutes)
                experienceLevel    = p.experienceLevel
                availableEquipment = Set(p.availableEquipment)
            }
        }
    }

    private func calcRow(_ label: String, value: Double) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(Int(value)) kcal/day").foregroundStyle(.secondary)
        }
    }

    private func save() async {
        guard let uid = appVM.currentUser?.uid else { return }
        isSaving = true
        let profile = UserProfile(
            id: uid, email: appVM.currentUser?.email ?? "",
            displayName: displayName.trimmingCharacters(in: .whitespaces),
            age: Int(age), weightKg: weightKg, heightCm: heightCm,
            sex: sex, activityLevel: activityLevel, fitnessGoal: goal,
            workoutFocus: focus, workoutMinutes: Int(workoutMinutes),
            joinedDate: appVM.profile?.joinedDate ?? Date(),
            experienceLevel: experienceLevel,
            availableEquipment: Array(availableEquipment)
        )
        await appVM.saveProfile(profile)
        isSaving = false
    }
}

// MARK: - NumericField

private struct NumericField: View {
    let label: String
    let unit: String
    @Binding var value: Double
    let step: Double
    let range: ClosedRange<Double>
    let fractionDigits: Int

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            HStack(spacing: 6) {
                TextField("", text: $text)
                    .keyboardType(fractionDigits > 0 ? .decimalPad : .numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 72)
                    .focused($focused)
                    .onChange(of: text) { raw in
                        let cleaned = raw.replacingOccurrences(of: ",", with: ".")
                        if let parsed = Double(cleaned) {
                            value = min(max(parsed, range.lowerBound), range.upperBound)
                        }
                    }
                    .onChange(of: value) { v in
                        // Sync from external changes (parent onAppear, stepper) only when not typing.
                        if !focused { text = formatted(v) }
                    }
                Text(unit)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .frame(minWidth: 28, alignment: .leading)
            }
            Stepper("", value: Binding(
                get: { value },
                set: { newVal in
                    value = newVal
                    text  = formatted(newVal)
                }
            ), in: range, step: step)
            .labelsHidden()
        }
        .onAppear { text = formatted(value) }
    }

    private func formatted(_ v: Double) -> String {
        fractionDigits > 0
            ? String(format: "%.\(fractionDigits)f", v)
            : String(Int(v.rounded()))
    }
}
