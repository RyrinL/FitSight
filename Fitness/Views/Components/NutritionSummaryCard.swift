import SwiftUI

struct NutritionSummaryCard: View {
    let calories: Double
    let calorieGoal: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    var targets: MacroTargets? = nil    // nil → show fractions of total only

    @State private var appeared = false

    private var calProgress: Double  { min(calories / max(calorieGoal, 1), 1) }
    private var remainingKcal: Double { max(calorieGoal - calories, 0) }

    private var totalMacroG: Double   { proteinG + carbsG + fatG }
    private var proteinFrac: Double   { totalMacroG > 0 ? proteinG / totalMacroG : 0.33 }
    private var carbsFrac: Double     { totalMacroG > 0 ? carbsG   / totalMacroG : 0.33 }
    private var fatFrac: Double       { totalMacroG > 0 ? fatG     / totalMacroG : 0.34 }

    var body: some View {
        VStack(spacing: 16) {
            headerRow
            calorieProgressBar
            macroSection
        }
        .glassCard()
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { appeared = true }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's Nutrition")
                    .font(.fitHeadline())
                HStack(spacing: 4) {
                    Text("\(Int(calories)) / \(Int(calorieGoal)) kcal")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                    if remainingKcal > 0 {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text("\(Int(remainingKcal)) left")
                            .font(.system(.caption, design: .rounded).weight(.medium))
                            .foregroundStyle(.mint)
                    }
                }
            }
            Spacer()
            Text("\(Int(calProgress * 100))%")
                .font(.fitMono(20))
                .foregroundStyle(calProgress >= 1 ? Color.fitOrange : Color.mint)
        }
    }

    // MARK: - Calorie bar

    private var calorieProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.secondary.opacity(0.12))
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(calProgress >= 1 ? FitGradient.energy : FitGradient.mint)
                    .frame(width: appeared ? geo.size.width * calProgress : 0, height: 8)
                    .animation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.1), value: appeared)
            }
        }
        .frame(height: 8)
    }

    // MARK: - Macros

    private var macroSection: some View {
        HStack(spacing: 20) {
            MacroDonut(
                proteinFraction: appeared ? proteinFrac : 0,
                carbsFraction:   appeared ? carbsFrac   : 0,
                fatFraction:     appeared ? fatFrac     : 0,
                size: 80
            )

            if let t = targets {
                macroGoalRows(targets: t)
            } else {
                macroSimpleRows
            }
            Spacer()
        }
    }

    private var macroSimpleRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            MacroRow(label: "Protein", grams: proteinG, goal: nil, color: .fitBlue)
            MacroRow(label: "Carbs",   grams: carbsG,   goal: nil, color: .fitOrange)
            MacroRow(label: "Fat",     grams: fatG,     goal: nil, color: .fitPurple)
        }
    }

    private func macroGoalRows(targets t: MacroTargets) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MacroRow(label: "Protein", grams: proteinG, goal: t.proteinG, color: .fitBlue)
            MacroRow(label: "Carbs",   grams: carbsG,   goal: t.carbsG,   color: .fitOrange)
            MacroRow(label: "Fat",     grams: fatG,     goal: t.fatG,     color: .fitPurple)
        }
    }
}

// MARK: - Donut chart

private struct MacroDonut: View {
    let proteinFraction: Double
    let carbsFraction: Double
    let fatFraction: Double
    let size: CGFloat

    private let lineWidth: CGFloat = 10

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.1), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fatFraction)
                .stroke(Color.fitPurple, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.3), value: fatFraction)
            Circle()
                .trim(from: fatFraction, to: fatFraction + carbsFraction)
                .stroke(Color.fitOrange, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.2), value: carbsFraction)
            Circle()
                .trim(from: fatFraction + carbsFraction,
                      to: fatFraction + carbsFraction + proteinFraction)
                .stroke(Color.fitBlue, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.1), value: proteinFraction)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Macro row (with optional goal bar)

private struct MacroRow: View {
    let label: String
    let grams: Double
    let goal: Double?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 4, height: 16)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if let g = goal {
                    Text("\(Int(grams))g / \(Int(g))g")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                } else {
                    Text("\(Int(grams))g")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
            if let g = goal, g > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(color.opacity(0.12)).frame(height: 4)
                        Capsule().fill(color)
                            .frame(width: geo.size.width * min(grams / g, 1), height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .frame(maxWidth: 160)
    }
}
