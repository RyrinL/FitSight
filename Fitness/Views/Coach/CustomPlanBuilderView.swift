import SwiftUI

// MARK: - CustomPlanBuilderView

struct CustomPlanBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    var existingPlan: WorkoutPlan?
    var onSave: (WorkoutPlan) -> Void

    @State private var planName  = "My Plan"
    @State private var days: [DraftDay] = Self.defaultDays()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    nameField
                    ForEach($days) { $day in
                        DraftDayCard(day: $day)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(existingPlan == nil ? "Create My Plan" : "Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(buildPlan())
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear { if let p = existingPlan { load(p) } }
    }

    // MARK: - Name field

    private var nameField: some View {
        HStack(spacing: 12) {
            Image(systemName: "pencil.line")
                .foregroundStyle(Color.fitPurple)
                .frame(width: 20)
            TextField("Plan name", text: $planName)
                .font(.body.weight(.semibold))
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Build & load

    private func buildPlan() -> WorkoutPlan {
        let workoutDays = days.map { d -> WorkoutDay in
            let blocks = d.exercises.map { ex -> ExerciseBlock in
                ExerciseBlock(id: ex.id, name: ex.name,
                              sets: ex.sets, repsLow: ex.repsLow, repsHigh: ex.repsHigh,
                              restSeconds: ex.restSeconds, tempo: "2-0-1",
                              cues: ex.cues, muscleGroup: ex.muscleGroup, equipment: ex.equipment)
            }
            return WorkoutDay(id: d.id, weekdayIndex: d.weekdayIndex, weekdayName: d.weekdayName,
                              sessionType: d.sessionType, exercises: blocks,
                              estimatedMinutes: blocks.isEmpty ? 0 : max(15, blocks.count * 8),
                              estimatedCalories: blocks.isEmpty ? 0 : max(80, blocks.count * 35),
                              notes: d.notes)
        }
        let totalSets = workoutDays.flatMap(\.exercises).reduce(0) { $0 + $1.sets }
        return WorkoutPlan(id: existingPlan?.id ?? UUID().uuidString,
                           userId: existingPlan?.userId ?? "",
                           createdAt: Date(),
                           goal: .maintenance, experience: .beginner,
                           equipment: [.bodyweight],
                           days: workoutDays, splitName: planName,
                           weeklyVolume: totalSets, notes: "Custom plan")
    }

    private func load(_ plan: WorkoutPlan) {
        planName = plan.splitName
        days = plan.days.map { d in
            DraftDay(id: d.id, weekdayIndex: d.weekdayIndex, weekdayName: d.weekdayName,
                     sessionType: d.sessionType, notes: d.notes,
                     exercises: d.exercises.map { ex in
                DraftExercise(id: ex.id, name: ex.name, sets: ex.sets,
                              repsLow: ex.repsLow, repsHigh: ex.repsHigh,
                              restSeconds: ex.restSeconds, cues: ex.cues,
                              muscleGroup: ex.muscleGroup, equipment: ex.equipment)
            })
        }
    }

    private static func defaultDays() -> [DraftDay] {
        let data: [(String, SessionType)] = [
            ("Monday","Push"), ("Tuesday","Pull"), ("Wednesday","Legs"),
            ("Thursday","Rest"), ("Friday","Full Body"), ("Saturday","Cardio"), ("Sunday","Rest")
        ].compactMap { name, raw in
            SessionType.allCases.first { $0.rawValue == raw }.map { (name, $0) }
        }
        return data.enumerated().map { i, pair in
            DraftDay(id: UUID().uuidString, weekdayIndex: i + 1,
                     weekdayName: pair.0, sessionType: pair.1, notes: "", exercises: [])
        }
    }
}

// MARK: - Draft models

struct DraftExercise: Identifiable {
    var id          = UUID().uuidString
    var name        = ""
    var sets        = 3
    var repsLow     = 8
    var repsHigh    = 12
    var restSeconds = 60
    var cues: [String]       = []
    var muscleGroup: MuscleGroup  = .fullBody
    var equipment: Equipment      = .bodyweight
}

struct DraftDay: Identifiable {
    var id: String
    var weekdayIndex: Int
    var weekdayName: String
    var sessionType: SessionType
    var notes: String
    var exercises: [DraftExercise]
}

// MARK: - DraftDayCard

private struct DraftDayCard: View {
    @Binding var day: DraftDay
    @State private var expanded = false
    @State private var showPicker = false

    var isRest: Bool { day.sessionType == .rest }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if expanded && !isRest { exerciseSection }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(isRest ? Color.clear : Color.fitPurple.opacity(0.18), lineWidth: 1))
        .sheet(isPresented: $showPicker) {
            ExercisePickerSheet(sessionType: day.sessionType) { template in
                day.exercises.append(DraftExercise(
                    name: template.name, cues: template.cues,
                    muscleGroup: template.muscleGroup, equipment: template.equipment
                ))
                expanded = true
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isRest ? Color(.tertiarySystemGroupedBackground) : Color.fitPurple)
                    .frame(width: 40, height: 40)
                Image(systemName: day.sessionType.symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isRest ? Color.secondary : .white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(day.weekdayName).font(.headline)
                sessionMenu
            }

            Spacer()

            if !isRest {
                // Exercise count badge
                if !day.exercises.isEmpty {
                    Text("\(day.exercises.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.fitPurple)
                        .clipShape(Capsule())
                }
                Button {
                    FitHaptic.impact(.light)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isRest else { return }
            FitHaptic.impact(.light)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { expanded.toggle() }
        }
    }

    private var sessionMenu: some View {
        Menu {
            ForEach(SessionType.allCases) { type in
                Button {
                    day.sessionType = type
                    if type == .rest { expanded = false }
                } label: {
                    Label(type.rawValue, systemImage: type.symbolName)
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(day.sessionType.rawValue)
                    .font(.subheadline).foregroundStyle(Color.fitPurple)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold)).foregroundStyle(Color.fitPurple.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Exercise section

    private var exerciseSection: some View {
        VStack(spacing: 0) {
            Divider().padding(.horizontal, 14)

            if day.exercises.isEmpty {
                emptyExercises
            } else {
                VStack(spacing: 0) {
                    ForEach(day.exercises.indices, id: \.self) { idx in
                        DraftExerciseRow(ex: $day.exercises[idx]) {
                            withAnimation {
                                var list = day.exercises
                                list.remove(at: idx)
                                day.exercises = list
                            }
                        }
                        if idx < day.exercises.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
            }

            // Add exercise button
            Button {
                FitHaptic.impact(.light)
                showPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.fitPurple)
                    Text("Add Exercise")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.fitPurple)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.fitPurple.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(14)
        }
    }

    private var emptyExercises: some View {
        VStack(spacing: 6) {
            Image(systemName: "dumbbell")
                .font(.title2).foregroundStyle(.secondary.opacity(0.4))
            Text("No exercises added").font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - DraftExerciseRow

private struct DraftExerciseRow: View {
    @Binding var ex: DraftExercise
    var onDelete: () -> Void

    private let restOptions = [30, 45, 60, 90, 120, 180, 300]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Muscle icon
            ZStack {
                Circle()
                    .fill(Color.fitPurple.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: muscleIcon(ex.muscleGroup))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.fitPurple)
            }

            VStack(alignment: .leading, spacing: 10) {
                // Name + delete
                HStack {
                    Text(ex.name.isEmpty ? "Exercise" : ex.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ex.name.isEmpty ? .secondary : .primary)
                    Spacer()
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }

                // Row 1: Sets + Rest
                HStack {
                    counterControl(label: "Sets", value: $ex.sets, range: 1...10)
                    Spacer()
                    restMenu
                }

                // Row 2: Reps
                repsControl
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func counterControl(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button { if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 } } label: {
                    Image(systemName: "minus").font(.caption.weight(.bold))
                        .frame(width: 24, height: 24)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Text("\(value.wrappedValue)")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .frame(minWidth: 20)

                Button { if value.wrappedValue < range.upperBound { value.wrappedValue += 1 } } label: {
                    Image(systemName: "plus").font(.caption.weight(.bold))
                        .frame(width: 24, height: 24)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var repsControl: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Reps").font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                // Low: − value +
                stepButton(minus: true)  { if ex.repsLow > 1 { ex.repsLow -= 1 } }
                Text("\(ex.repsLow)").font(.subheadline.weight(.bold)).monospacedDigit().frame(minWidth: 20)
                stepButton(minus: false) { ex.repsLow = min(ex.repsLow + 1, ex.repsHigh) }

                Text("–").foregroundStyle(.secondary).padding(.horizontal, 2)

                // High: − value +
                stepButton(minus: true)  { if ex.repsHigh > ex.repsLow { ex.repsHigh -= 1 } }
                Text("\(ex.repsHigh)").font(.subheadline.weight(.bold)).monospacedDigit().frame(minWidth: 20)
                stepButton(minus: false) { ex.repsHigh += 1 }
            }
        }
    }

    private func stepButton(minus: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: minus ? "minus" : "plus")
                .font(.caption.weight(.bold))
                .frame(width: 26, height: 26)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var restMenu: some View {
        VStack(spacing: 4) {
            Text("Rest").font(.caption2).foregroundStyle(.secondary)
            Menu {
                ForEach(restOptions, id: \.self) { s in
                    Button(restLabel(s)) { ex.restSeconds = s }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(restLabel(ex.restSeconds))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func restLabel(_ s: Int) -> String {
        let m = s / 60, sec = s % 60
        if m > 0 { return sec > 0 ? "\(m)m \(sec)s" : "\(m)m" }
        return "\(sec)s"
    }

    private func muscleIcon(_ group: MuscleGroup) -> String {
        switch group {
        case .chest:      return "arrow.up.heart"
        case .back:       return "figure.strengthtraining.traditional"
        case .shoulders:  return "arrow.up.and.down.and.arrow.left.and.right"
        case .biceps, .triceps: return "dumbbell.fill"
        case .quads, .hamstrings, .glutes, .calves: return "figure.walk"
        case .core:       return "circle.grid.cross"
        case .fullBody:   return "figure.highintensity.intervaltraining"
        case .cardio:     return "figure.run"
        }
    }
}

// MARK: - Exercise picker sheet

private struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let sessionType: SessionType
    var onSelect: (ExerciseTemplate) -> Void

    @State private var search = ""

    private var filtered: [ExerciseTemplate] {
        let pool = sessionType == .rest
            ? ExerciseLibrary.all
            : ExerciseLibrary.all.filter { $0.sessionTypes.contains(sessionType) }
        guard !search.isEmpty else { return pool }
        return pool.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private var grouped: [(MuscleGroup, [ExerciseTemplate])] {
        let groups = Dictionary(grouping: filtered, by: \.muscleGroup)
        return groups.sorted { $0.key.rawValue < $1.key.rawValue }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped, id: \.0) { group, exercises in
                    Section(group.rawValue) {
                        ForEach(exercises, id: \.name) { template in
                            Button {
                                FitHaptic.impact(.light)
                                onSelect(template)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(template.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text(template.equipment.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(Color.fitPurple)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search exercises")
            .navigationTitle("Choose Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
