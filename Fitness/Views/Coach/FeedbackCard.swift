import SwiftUI

// MARK: - FeedbackCard
//
// Displays one coaching cue with a severity-coloured background.
// Animates text transitions so rapid cue changes don't flash.

struct FeedbackCard: View {
    let message:  String
    let severity: FormSeverity

    var body: some View {
        Text(message)
            .font(.system(.footnote, design: .rounded).weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 200, alignment: .leading)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(backgroundStyle)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            // Transition on message identity so SwiftUI morphs smoothly between cues.
            .id(message)
            .transition(.opacity.combined(with: .move(edge: .leading)))
            .animation(.easeInOut(duration: 0.22), value: message)
    }

    private var backgroundStyle: some ShapeStyle {
        switch severity {
        case .good:    return AnyShapeStyle(Color.mint.opacity(0.85))
        case .caution: return AnyShapeStyle(Color.fitOrange.opacity(0.85))
        case .error:   return AnyShapeStyle(Color.red.opacity(0.90))
        }
    }
}

// MARK: - ConfidenceArc
//
// Circular arc gauge showing Vision detection confidence (0–100).
// Colour transitions: mint (strong) → orange (marginal) → red (unreliable).

struct ConfidenceArc: View {
    let value: Int   // 0–100

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Track
                Circle()
                    .stroke(.white.opacity(0.15), lineWidth: 3)
                    .frame(width: 44, height: 44)
                // Fill arc
                Circle()
                    .trim(from: 0, to: Double(value) / 100)
                    .stroke(arcColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 44, height: 44)
                    .animation(.easeOut(duration: 0.25), value: value)
                // Label
                Text("\(value)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            Text("CONF")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var arcColor: Color {
        value >= 70 ? .mint : value >= 40 ? .fitOrange : .fitRed
    }
}

// MARK: - FormScoreBadge
//
// Compact rectangle showing the smoothed rolling form score.

struct FormScoreBadge: View {
    let score: Int   // 0–100

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(badgeColor.opacity(0.25))
                    .frame(width: 44, height: 30)
                Text("\(score)")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(badgeColor)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.25), value: score)
            }
            Text("FORM")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var badgeColor: Color {
        score >= 80 ? .mint : score >= 55 ? .fitOrange : .fitRed
    }
}

// MARK: - RepCounter
//
// Large-type rep counter with a spring animation on increment.

struct RepCounter: View {
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("REPS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.55))
            Text("\(count)")
                .font(.system(size: 58, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.spring(response: 0.28, dampingFraction: 0.62), value: count)
        }
        .padding(16)
        .background(.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }
}

// MARK: - BackendBadge
//
// Shows which pose-detection backend is active: MoveNet or Vision.

struct BackendBadge: View {
    let backend: PoseBackend

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: backend == .moveNet ? "cpu.fill" : "eye.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(backend == .moveNet ? Color.fitOrange : Color.mint)
            Text(backend == .moveNet ? "MOVENET" : "VISION")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.black.opacity(0.40))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(
            backend == .moveNet ? Color.fitOrange.opacity(0.5) : Color.mint.opacity(0.3),
            lineWidth: 1)
        )
    }
}

// MARK: - LivePill
//
// Pulsing "LIVE" indicator shown when the camera session is running.

struct LivePill: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
            Text("LIVE")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.40))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
    }
}
