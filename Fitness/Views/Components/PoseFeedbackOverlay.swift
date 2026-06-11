import SwiftUI

struct PoseFeedbackOverlay: View {
    let exercise: String        // exercise name string (e.g. "Squat")
    let feedback: String
    let repCount: Int
    let confidence: Int         // 0–100
    let formScore: Int          // 0–100
    let severity: FormSeverity
    let isLive: Bool

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            bottomBar
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                // Exercise label pill.
                Text(exercise.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))

                // Feedback bubble — colour driven by severity.
                Text(feedback)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(feedbackBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .id(feedback)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                    .animation(.easeInOut(duration: 0.25), value: feedback)
            }

            Spacer()

            // Right column: confidence gauge + form score.
            VStack(spacing: 10) {
                confidenceGauge
                formScoreBadge
            }
        }
        .padding()
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(alignment: .bottom) {
            repCounter
            Spacer()
            if isLive { liveIndicator }
        }
        .padding()
    }

    private var repCounter: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("REPS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.6))
            Text("\(repCount)")
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: repCount)
        }
        .padding(16)
        .background(.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 1))
    }

    private var liveIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1))
            Text("LIVE")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.4))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Confidence gauge (circular arc)

    private var confidenceGauge: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.15), lineWidth: 3)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: Double(confidence) / 100)
                    .stroke(confidenceColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 44, height: 44)
                    .animation(.easeOut(duration: 0.3), value: confidence)
                Text("\(confidence)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            Text("CONF")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Form score badge

    private var formScoreBadge: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(formScoreColor.opacity(0.25))
                    .frame(width: 44, height: 32)
                Text("\(formScore)")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(formScoreColor)
                    .monospacedDigit()
                    .animation(.easeOut(duration: 0.3), value: formScore)
            }
            Text("FORM")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Helpers

    private var feedbackBackground: some ShapeStyle {
        switch severity {
        case .good:    return AnyShapeStyle(Color.mint.opacity(0.80))
        case .caution: return AnyShapeStyle(Color.fitOrange.opacity(0.80))
        case .error:   return AnyShapeStyle(Color.red.opacity(0.85))
        }
    }

    private var confidenceColor: Color {
        confidence >= 70 ? .mint : confidence >= 40 ? .fitOrange : .fitRed
    }

    private var formScoreColor: Color {
        formScore >= 80 ? .mint : formScore >= 55 ? .fitOrange : .fitRed
    }
}
