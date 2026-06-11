import SwiftUI

struct WorkoutCard: View {
    let recommendation: WorkoutRecommendation
    var onLog: (() -> Void)? = nil
    @State private var isExpanded = false
    @State private var isLogging = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(alignment: .top, spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(FitGradient.mint)
                        .frame(width: 46, height: 46)
                        .fitShadow(color: .mint, radius: 6)
                    Image(systemName: recommendation.symbolName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(.fitHeadline())
                    Text(recommendation.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(Circle())
            }
            .contentShape(Rectangle())
            .onTapGesture {
                FitHaptic.impact(.light)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    isExpanded.toggle()
                }
            }

            // Stats strip
            HStack(spacing: 0) {
                StatChip(icon: "clock",     label: "\(recommendation.minutes) min", color: .mint)
                Divider().frame(height: 20).padding(.horizontal, 8)
                StatChip(icon: "flame.fill", label: "\(recommendation.calories) kcal", color: .fitOrange)
                Divider().frame(height: 20).padding(.horizontal, 8)
                StatChip(icon: "gauge.with.dots.needle.50percent", label: recommendation.intensity, color: .fitPurple)
            }
            .padding(.top, 14)

            // Expandable exercises
            if isExpanded {
                Divider().padding(.vertical, 12)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Exercises")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.8)

                    ForEach(recommendation.exercises) { exercise in
                        ExerciseRow(exercise: exercise)
                            .transition(.move(edge: .top).combined(with: .opacity))
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
                            .background {
                                if isLogging { Color.mint.opacity(0.15) } else { FitGradient.mint }
                            }
                            .foregroundStyle(isLogging ? .mint : .white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .padding(.top, 6)
                        .disabled(isLogging)
                    }
                }
            }
        }
        .glassCard()
    }
}

struct ExerciseRow: View {
    let exercise: ExerciseBlock

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(exercise.muscleGroup.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(exercise.setsRepsLabel)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.mint)
                Text("rest \(exercise.restLabel)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct StatChip: View {
    let icon: String
    let label: String
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
    }
}
