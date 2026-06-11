import SwiftUI

// MARK: - Single achievement badge

struct AchievementBadge: View {
    let achievement: Achievement
    var size: CGFloat = 80

    @State private var appeared = false
    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 8) {
            badgeIcon
            labelBlock
        }
        .scaleEffect(isPressed ? 0.92 : (appeared ? 1 : 0.6))
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.05)) {
                appeared = true
            }
        }
        .onTapGesture {
            guard achievement.isEarned else { return }
            FitHaptic.impact(.light)
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPressed = false }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(achievement.title): \(achievement.description)")
        .accessibilityValue(achievement.isEarned ? "Earned" : "Locked, \(Int(achievement.progress * 100))% complete")
    }

    // MARK: - Icon circle

    private var badgeIcon: some View {
        ZStack {
            if achievement.isEarned {
                Circle()
                    .fill(tierGradient)
                    .frame(width: size, height: size)
                    .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 2))
                    .fitShadow(color: tierShadowColor, radius: 12)
                    .overlay(shimmerOverlay)
            } else {
                Circle()
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .frame(width: size, height: size)
                    .overlay(Circle().stroke(.secondary.opacity(0.2), lineWidth: 1))
            }

            Image(systemName: achievement.symbolName)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(achievement.isEarned ? Color.white : Color.secondary)
                .scaleEffect(appeared && achievement.isEarned ? 1.0 : 0.85)
                .animation(.spring(response: 0.4, dampingFraction: 0.55), value: appeared)
        }
    }

    // MARK: - Label block (title + description + optional progress bar)

    private var labelBlock: some View {
        VStack(spacing: 2) {
            Text(achievement.title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(achievement.isEarned ? Color.primary : Color.secondary)
            Text(achievement.description)
                .font(.system(size: 9, weight: .regular))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if !achievement.isEarned && achievement.targetValue > 1 {
                progressCapsule
                    .padding(.top, 2)
            }
        }
        .frame(width: size)
    }

    private var progressCapsule: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15)).frame(height: 3)
                Capsule()
                    .fill(tierProgressColor)
                    .frame(width: geo.size.width * achievement.progress, height: 3)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Shimmer

    @ViewBuilder
    private var shimmerOverlay: some View {
        if achievement.isEarned {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.35), .clear, .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .clipShape(Circle())
        }
    }

    // MARK: - Tier helpers

    private var tierGradient: LinearGradient {
        switch achievement.tier {
        case .bronze: return FitGradient.bronze
        case .silver: return FitGradient.silver
        case .gold:   return FitGradient.gold
        }
    }

    private var tierShadowColor: Color {
        switch achievement.tier {
        case .bronze: return Color(hex: "CD7F32")
        case .silver: return Color(hex: "C8C8C8")
        case .gold:   return Color.fitGold
        }
    }

    private var tierProgressColor: Color {
        switch achievement.tier {
        case .bronze: return Color(hex: "CD7F32")
        case .silver: return Color(hex: "C8C8C8")
        case .gold:   return Color.fitGold
        }
    }
}

// MARK: - Achievement grid

struct AchievementGrid: View {
    let achievements: [Achievement]
    private let columns = [GridItem(.adaptive(minimum: 80), spacing: 16)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(achievements) { achievement in
                AchievementBadge(achievement: achievement)
            }
        }
    }
}

// MARK: - Unlock banner (shown when a new achievement is earned)

struct AchievementUnlockBanner: View {
    let achievement: Achievement
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tierGradient)
                    .frame(width: 46, height: 46)
                    .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1.5))
                Image(systemName: achievement.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Achievement Unlocked!")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(achievement.title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.secondary)
                    .font(.title3)
            }
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
        .padding(.horizontal, 16)
        .scaleEffect(appeared ? 1 : 0.85)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { onDismiss() }
        }
    }

    private var tierGradient: LinearGradient {
        switch achievement.tier {
        case .bronze: return FitGradient.bronze
        case .silver: return FitGradient.silver
        case .gold:   return FitGradient.gold
        }
    }
}
