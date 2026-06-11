import SwiftUI

struct OnboardingView: View {
    @Binding var isComplete: Bool

    @State private var currentPage = 0
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "figure.strengthtraining.traditional",
            gradient: FitGradient.mint,
            glowColor: .mint,
            title: "Welcome to FitSight",
            subtitle: "Your AI-powered personal trainer, coach, and nutritionist — all in one app.",
            accentText: "Let's build your best self."
        ),
        OnboardingPage(
            icon: "heart.text.square.fill",
            gradient: FitGradient.energy,
            glowColor: .fitOrange,
            title: "Syncs with Apple Health",
            subtitle: "FitSight reads your active calories, steps, and heart rate — so your goals always reflect your real progress.",
            accentText: "No manual entry required."
        ),
        OnboardingPage(
            icon: "camera.viewfinder",
            gradient: FitGradient.purple,
            glowColor: .fitPurple,
            title: "Live Form Coaching",
            subtitle: "Point the camera at yourself and get instant pose feedback for squats, push-ups, lunges, and planks.",
            accentText: "Powered 100% on-device."
        ),
        OnboardingPage(
            icon: "sparkles",
            gradient: FitGradient.gold,
            glowColor: .fitGold,
            title: "Your AI Coach is Ready",
            subtitle: "Ask questions, get workout plans, nutrition advice, and recovery tips from your personal AI coach.",
            accentText: "Let's set up your profile."
        )
    ]

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: currentPage)

                // Bottom controls
                VStack(spacing: 24) {
                    // Dots
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { i in
                            Capsule()
                                .fill(i == currentPage ? Color.mint : Color.secondary.opacity(0.3))
                                .frame(width: i == currentPage ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: currentPage)
                        }
                    }

                    // CTA button
                    Button {
                        FitHaptic.impact(.medium)
                        if currentPage < pages.count - 1 {
                            withAnimation { currentPage += 1 }
                        } else {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                isComplete = true
                            }
                        }
                    } label: {
                        HStack {
                            Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                                .font(.system(.body, design: .rounded).weight(.bold))
                            Image(systemName: currentPage < pages.count - 1 ? "arrow.right" : "checkmark")
                                .font(.body.weight(.bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(pages[currentPage].gradient)
                                .fitShadow(color: pages[currentPage].glowColor, radius: 14)
                        )
                        .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 28)

                    // Skip
                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            withAnimation { isComplete = true }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    } else {
                        Color.clear.frame(height: 20)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Page model

private struct OnboardingPage {
    let icon: String
    let gradient: LinearGradient
    let glowColor: Color
    let title: String
    let subtitle: String
    let accentText: String
}

// MARK: - Page view

private struct OnboardingPageView: View {
    let page: OnboardingPage

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon circle
            ZStack {
                Circle()
                    .fill(page.gradient)
                    .frame(width: 140, height: 140)
                    .fitShadow(color: page.glowColor, radius: 28)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)

                // Halo ring
                Circle()
                    .stroke(page.glowColor.opacity(0.25), lineWidth: 1.5)
                    .frame(width: 170, height: 170)
                    .scaleEffect(appeared ? 1 : 0.7)
                    .opacity(appeared ? 1 : 0)

                Image(systemName: page.icon)
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundStyle(.white)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .opacity(appeared ? 1 : 0)
            }
            .animation(.spring(response: 0.65, dampingFraction: 0.7).delay(0.05), value: appeared)

            // Text
            VStack(spacing: 14) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                Text(page.subtitle)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                Text(page.accentText)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(page.glowColor)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.18), value: appeared)

            Spacer()
        }
        .onAppear {
            appeared = false
            withAnimation { appeared = true }
        }
        .onDisappear { appeared = false }
    }
}
