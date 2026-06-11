import SwiftUI

struct LoginView: View {
    @ObservedObject var appVM: AppViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var logoScale: CGFloat = 0.6
    @State private var formOpacity: Double = 0

    var body: some View {
        ZStack {
            // Gradient background
            Color(.systemBackground).ignoresSafeArea()
            FitGradient.hero.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 36) {
                    Spacer().frame(height: 60)

                    // Logo
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(FitGradient.mint)
                                .frame(width: 90, height: 90)
                                .fitShadow(color: .mint, radius: 20)
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .scaleEffect(logoScale)
                        .onAppear {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) {
                                logoScale = 1
                            }
                        }

                        Text("FitSight")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                        Text(isSignUp ? "Create your account" : "Welcome back")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    // Form card
                    VStack(spacing: 14) {
                        FitTextField(icon: "envelope.fill", placeholder: "Email", text: $email)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)

                        FitTextField(icon: "lock.fill", placeholder: "Password", text: $password, isSecure: true)
                            .textContentType(isSignUp ? .newPassword : .password)

                        if let msg = errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(msg).font(.footnote)
                            }
                            .foregroundStyle(Color.fitRed)
                            .padding(.horizontal, 4)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Submit button
                        Button {
                            Task { await submit() }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(FitGradient.mint)
                                    .fitShadow(color: .mint, radius: 12)
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(isSignUp ? "Create Account" : "Sign In")
                                        .font(.system(.body, design: .rounded).weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                        }
                        .disabled(isLoading || email.isEmpty || password.isEmpty)
                        .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)
                    }
                    .glassCard(padding: 20)
                    .opacity(formOpacity)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.5).delay(0.2)) { formOpacity = 1 }
                    }

                    // Toggle
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isSignUp.toggle()
                            errorMessage = nil
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                .foregroundStyle(.secondary)
                            Text(isSignUp ? "Sign In" : "Sign Up")
                                .foregroundStyle(.mint)
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private func submit() async {
        isLoading = true
        errorMessage = nil
        FitHaptic.impact()
        do {
            if isSignUp { try await appVM.signUp(email: email, password: password) }
            else         { try await appVM.signIn(email: email, password: password) }
            FitHaptic.success()
        } catch {
            FitHaptic.warning()
            withAnimation { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }
}

// MARK: - Custom text field

private struct FitTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.system(.body, design: .rounded))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.mint.opacity(text.isEmpty ? 0 : 0.4), lineWidth: 1.5)
        )
        .animation(.easeOut(duration: 0.2), value: text.isEmpty)
    }
}
