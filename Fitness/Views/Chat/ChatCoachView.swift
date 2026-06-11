import SwiftUI

struct ChatCoachView: View {
    @ObservedObject var appVM: AppViewModel
    @ObservedObject var dashVM: DashboardViewModel
    @StateObject private var vm: ChatViewModel

    private let quickPrompts = [
        "Suggest a workout for today",
        "Give me recovery tips",
        "Nutrition advice for my goal",
        "Explain push-up form",
        "Motivate me"
    ]

    init(appVM: AppViewModel, dashVM: DashboardViewModel) {
        self.appVM = appVM
        self.dashVM = dashVM
        _vm = StateObject(wrappedValue: ChatViewModel(db: appVM.db))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                contextCard
                quickPromptRow
                messageList
                inputBar
            }
            .navigationTitle("AI Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        Task { await vm.clearHistory(uid: appVM.currentUser?.uid ?? "") }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Clear chat")
                }
            }
            .task {
                await vm.loadHistory(uid: appVM.currentUser?.uid ?? "")
                if vm.messages.isEmpty {
                    vm.messages.append(.assistant(greetingMessage))
                }
            }
            .onChange(of: dashVM.activeEnergy) { _ in updateContext() }
            .onAppear { updateContext() }
        }
    }

    // MARK: - Context card

    private var contextCard: some View {
        HStack(spacing: 10) {
            contextChip(
                icon: "target",
                text: appVM.profile?.fitnessGoal.rawValue ?? "Set Goal",
                color: .mint
            )
            contextChip(
                icon: "flame.fill",
                text: "\(appVM.streak.currentStreak)d streak",
                color: appVM.streak.currentStreak > 0 ? .orange : .secondary
            )
            Spacer()
            calorieProgressView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private func contextChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private var calorieProgressView: some View {
        let active = Int(dashVM.activeEnergy)
        let goal   = Int(dashVM.dailyCalorieGoal)
        let pct    = dashVM.dailyCalorieGoal > 0
            ? min(dashVM.activeEnergy / dashVM.dailyCalorieGoal, 1.0) : 0.0
        return HStack(spacing: 6) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.mint.opacity(0.15))
                    .frame(width: 60, height: 6)
                Capsule()
                    .fill(Color.mint)
                    .frame(width: max(60.0 * pct, 0), height: 6)
            }
            Text("\(active)/\(goal) kcal")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Quick prompts

    private var quickPromptRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickPrompts, id: \.self) { prompt in
                    Button {
                        vm.draft = prompt
                        Task { await vm.send(uid: appVM.currentUser?.uid ?? "") }
                    } label: {
                        Text(prompt)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.mint.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isGenerating)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(vm.messages) { msg in
                        if msg.role != .system {
                            ChatBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                    if vm.isGenerating {
                        HStack {
                            ProgressView()
                            Text("Coaching…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .id("generating")
                    }
                    if let err = vm.errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical, 12)
            }
            .onChange(of: vm.messages.count) { _ in
                withAnimation { proxy.scrollTo(vm.messages.last?.id ?? "generating", anchor: .bottom) }
            }
            .onChange(of: vm.isGenerating) { _ in
                withAnimation { proxy.scrollTo("generating", anchor: .bottom) }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask your coach…", text: $vm.draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(10)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                Task { await vm.send(uid: appVM.currentUser?.uid ?? "") }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.mint)
                    .opacity(
                        vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isGenerating
                            ? 0.35 : 1.0
                    )
            }
            .disabled(vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isGenerating)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.background)
    }

    // MARK: - Helpers

    private var greetingMessage: String {
        if let profile = appVM.profile {
            return "Hi! I'm your FitSight AI coach. I can see you're working on \(profile.fitnessGoal.rawValue.lowercased()) with a \(profile.experienceLevel.rawValue.lowercased()) program. Ask me anything about training, nutrition, recovery, or form!"
        }
        return "Hi! I'm your FitSight AI coach. Ask me anything about training, nutrition, recovery, or form."
    }

    private func updateContext() {
        guard let profile = appVM.profile else { return }
        vm.context = CoachContext(
            profile: profile,
            recentWorkouts: Array(dashVM.workoutHistory.prefix(5)),
            streak: appVM.streak,
            activeKcal: dashVM.activeEnergy,
            dailyGoalKcal: dashVM.dailyCalorieGoal
        )
    }
}

// MARK: - Chat bubble

private struct ChatBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }
            Text(message.content)
                .font(.subheadline)
                .padding(12)
                .background(isUser ? Color.mint : Color(.secondarySystemGroupedBackground))
                .foregroundStyle(isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
        .accessibilityLabel("\(isUser ? "You" : "Coach"): \(message.content)")
    }
}
