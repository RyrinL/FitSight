import SwiftUI

// MARK: - Main animated calorie ring

struct CalorieProgressRing: View {
    let calorieProgress: Double   // 0…1  (active kcal / goal)
    let stepsProgress: Double     // 0…1
    let workoutProgress: Double   // 0…1
    var centerLabel: String = ""
    var size: CGFloat = 200

    @State private var animCal:     Double = 0
    @State private var animSteps:   Double = 0
    @State private var animWorkout: Double = 0

    private let lineWidth: CGFloat = 18
    private let gap: CGFloat = 8

    var body: some View {
        ZStack {
            // Outer ring — calories (mint)
            RingLayer(progress: animCal, lineWidth: lineWidth,
                      gradient: FitGradient.mint, trackColor: .mint.opacity(0.12))
                .frame(width: size, height: size)
                .fitShadow(color: .mint, radius: 10)

            // Middle ring — steps / BMR (blue)
            RingLayer(progress: animSteps, lineWidth: lineWidth,
                      gradient: FitGradient.steps, trackColor: .fitBlue.opacity(0.12))
                .frame(width: size - (lineWidth + gap) * 2,
                       height: size - (lineWidth + gap) * 2)
                .fitShadow(color: .fitBlue, radius: 8)

            // Inner ring — workout / active target (orange)
            RingLayer(progress: animWorkout, lineWidth: lineWidth,
                      gradient: FitGradient.energy, trackColor: .fitOrange.opacity(0.12))
                .frame(width: size - (lineWidth + gap) * 4,
                       height: size - (lineWidth + gap) * 4)
                .fitShadow(color: .fitOrange, radius: 6)

            // Center label
            if !centerLabel.isEmpty {
                VStack(spacing: 2) {
                    Text(centerLabel)
                        .font(.fitDisplay(size * 0.18))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("kcal")
                        .font(.system(size: size * 0.07, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear { animateRings() }
        .onChange(of: calorieProgress) { _ in animateRings() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calorie progress \(Int(calorieProgress * 100))%. Steps \(Int(stepsProgress * 100))%. Workout \(Int(workoutProgress * 100))%.")
    }

    private func animateRings() {
        withAnimation(.spring(response: 0.9, dampingFraction: 0.75).delay(0.1)) {
            animCal = min(calorieProgress, 1)
        }
        withAnimation(.spring(response: 0.9, dampingFraction: 0.75).delay(0.2)) {
            animSteps = min(stepsProgress, 1)
        }
        withAnimation(.spring(response: 0.9, dampingFraction: 0.75).delay(0.3)) {
            animWorkout = min(workoutProgress, 1)
        }
    }
}

// MARK: - Single ring layer

struct RingLayer: View {
    let progress: Double
    let lineWidth: CGFloat
    let gradient: LinearGradient
    let trackColor: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if progress > 0.01 { glowDot }
        }
    }

    private var glowDot: some View {
        GeometryReader { geo in
            let angle = Angle.degrees(-90 + progress * 360)
            let r = geo.size.width / 2 - lineWidth / 2
            let x = geo.size.width / 2 + r * cos(CGFloat(angle.radians))
            let y = geo.size.height / 2 + r * sin(CGFloat(angle.radians))
            Circle()
                .fill(.white)
                .frame(width: lineWidth * 0.6, height: lineWidth * 0.6)
                .shadow(color: .white.opacity(0.8), radius: 4)
                .position(x: x, y: y)
        }
    }
}

// MARK: - Legend

struct RingLegend: View {
    let calorieGoal: Int
    let calorieActual: Int
    let stepsActual: Int
    let workoutMinutesActual: Int

    var body: some View {
        HStack(spacing: 20) {
            LegendItem(color: .mint,      label: "Calories", value: "\(calorieActual)/\(calorieGoal)")
            LegendItem(color: .fitBlue,   label: "Steps",    value: "\(stepsActual)")
            LegendItem(color: .fitOrange, label: "Workout",  value: "\(workoutMinutesActual)m")
        }
    }
}

private struct LegendItem: View {
    let color: Color
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(value).font(.fitMono(13))
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
        }
    }
}
