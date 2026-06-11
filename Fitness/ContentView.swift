import SwiftUI

struct ContentView: View {
    @StateObject private var appVM = AppViewModel()
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    var body: some View {
        Group {
            if !onboardingComplete {
                OnboardingView(isComplete: $onboardingComplete)
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else if !appVM.isAuthenticated {
                LoginView(appVM: appVM)
                    .transition(.opacity)
            } else if appVM.isLoadingProfile {
                loadingScreen
            } else if !appVM.profileComplete {
                ProfileSetupView(appVM: appVM)
                    .transition(.opacity)
            } else {
                MainTabView(appVM: appVM)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: onboardingComplete)
        .animation(.easeInOut(duration: 0.25), value: appVM.isAuthenticated)
        .animation(.easeInOut(duration: 0.25), value: appVM.profileComplete)
        .tint(.mint)
    }

    private var loadingScreen: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            FitGradient.hero.ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .tint(.mint)
                    .scaleEffect(1.4)
                Text("Loading your profile…")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Main tab view

private struct MainTabView: View {
    @ObservedObject var appVM: AppViewModel
    @StateObject private var dashVM: DashboardViewModel


    init(appVM: AppViewModel) {
        self.appVM = appVM
        _dashVM = StateObject(wrappedValue: DashboardViewModel(db: appVM.db, healthKit: appVM.healthKit))
    }

    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                TodayView(appVM: appVM, dashVM: dashVM)
                    .tabItem { Label("Today", systemImage: "target") }.tag(0)

                CoachView(appVM: appVM, dashVM: dashVM)
                    .tabItem { Label( ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;"Coach", systemImage: "figure.strengthtraining.traditional") }.tag(1)

                FormCoachView()
                    .tabItem { Label("Form", systemImage: "camera.viewfinder") }.tag(2)

                NutritionView(appVM: appVM)
                    .tabItem { Label("Nutrition", systemImage: "fork.knife") }.tag(3)

                MoreView(appVM: appVM, dashVM: dashVM)
                    .tabItem { Label("More", systemImage: "ellipsis") }.tag(4)
            }
.task {
                appVM.healthKit.requestAuthorization()
                _ = await NotificationService.shared.requestAuthorization()
                await NotificationService.shared.scheduleWorkoutReminder()
            }

            if let achievement = appVM.newlyUnlocked.first {
                AchievementUnlockBanner(achievement: achievement) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        appVM.dismissUnlockBanner()
                    }
                }
                .padding(.bottom, 90)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appVM.newlyUnlocked.isEmpty)
    }
}
