import SwiftUI
import AVFoundation

// MARK: - FormCoachView
//
// Camera + pose analysis view. Uses CameraFormCoach which supports four
// exercises: Squat, Push-up, Lunge, Plank — all analyzed 100 % on-device
// via VNDetectHumanBodyPoseRequest.
//
// Data flow (read top → bottom):
//   CameraFormCoach
//     └─ AVCaptureSession         → feeds frames
//     └─ VNDetectHumanBodyPoseRequest → per-frame pose observation
//     └─ FormAnalyzer             → per-exercise rule-based feedback
//     └─ PoseProcessor (actor)    → smoothing, scoring, debounce, rep-count
//     └─ @Published state         → SwiftUI renders below
//
// View tree:
//   ZStack (full screen)
//     ├── CameraPreviewView       (AVCaptureVideoPreviewLayer)
//     ├── SkeletonOverlayView     (Canvas — bones + joints)
//     ├── liveHUD                 (feedback card, gauges, rep counter)
//     └── CameraPermissionGate   (shown when camera not authorised)
//   +
//   VStack bottom sheet           (exercise picker, metric tiles, reset, disclaimer)

struct FormCoachView: View {

    @StateObject private var coach = CameraFormCoach()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // ── Layer 1: camera feed + skeleton (behind nav bar) ──
                cameraLayer
                    .ignoresSafeArea(edges: .top)

                // ── Layer 2: HUD — respects safe area so it clears the nav bar ──
                if coach.isRunning || coach.repCount > 0 {
                    liveHUD
                }

                // ── Layer 3: permission gate ──
                if coach.permission != .authorized {
                    CameraPermissionGate(
                        message:    coach.permissionMessage,
                        permission: coach.permission,
                        onEnable:   { coach.requestAccessIfNeeded() }
                    )
                }

                // ── Layer 4: bottom control panel ──
                controlPanel
            }
            .navigationTitle("Form Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                voiceToggleButton
                sessionToggleButton
            }
            .onAppear   { coach.requestAccessIfNeeded() }
            .onDisappear { coach.stopSession() }
        }
    }

    // MARK: - Camera layer (preview + skeleton only)

    @ViewBuilder
    private var cameraLayer: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewView(session: coach.session)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if coach.isRunning && !coach.poseDisplayPoints.isEmpty {
                SkeletonOverlayView(
                    points:       coach.poseDisplayPoints,
                    issueJoints:  coach.issueJoints,
                    sourceAspect: coach.sourceAspect
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Live HUD

    private var liveHUD: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                feedbackColumn
                Spacer()
                gaugeColumn
            }
            .padding()

            Spacer()

            HStack(alignment: .bottom) {
                RepCounter(count: coach.repCount)
                Spacer()
                if coach.isRunning { LivePill() }
            }
            .padding()
        }
    }

    private var feedbackColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Exercise label pill — updates when the picker changes.
            Text(coach.currentExercise.rawValue.uppercased())
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(2)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                .animation(.easeInOut(duration: 0.2), value: coach.currentExercise)

            FeedbackCard(message: coach.feedback, severity: coach.feedbackSeverity)
        }
    }

    private var gaugeColumn: some View {
        VStack(spacing: 12) {
            ConfidenceArc(value: coach.poseConfidencePercent)
            FormScoreBadge(score: coach.formScore)
        }
    }

    // MARK: - Control panel (bottom sheet)

    private var controlPanel: some View {
        VStack(spacing: 14) {
            // Exercise picker — switches the form-analysis rules immediately.
            Picker("Exercise", selection: $coach.currentExercise) {
                ForEach(TrackedExercise.allCases) { exercise in
                    Text(exercise.rawValue).tag(exercise)
                }
            }
            .pickerStyle(.segmented)

            // Metric tiles row.
            HStack(spacing: 10) {
                MetricTile(title: "Reps",
                           value: "\(coach.repCount)",
                           unit: "reps")
                MetricTile(title: "Form",
                           value: "\(coach.formScore)",
                           unit: "/100",
                           tint: formScoreTint)
                MetricTile(title: "Confidence",
                           value: "\(coach.poseConfidencePercent)",
                           unit: "%",
                           tint: confidenceTint)
            }

            if coach.repCount > 0 {
                Button {
                    FitHaptic.impact(.light)
                    coach.resetReps()
                } label: {
                    Label("Reset reps", systemImage: "arrow.counterclockwise")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text("Pose analysis runs 100% on-device. Not medical advice.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var voiceToggleButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                FitHaptic.impact(.light)
                coach.voiceEnabled.toggle()
            } label: {
                Image(systemName: coach.voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.title3)
                    .foregroundStyle(coach.voiceEnabled ? .mint : .secondary)
            }
            .accessibilityLabel(coach.voiceEnabled ? "Turn off voice feedback" : "Turn on voice feedback")
        }
    }

    @ToolbarContentBuilder
    private var sessionToggleButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                if coach.isRunning { coach.stopSession() } else { coach.requestAccessIfNeeded() }
            } label: {
                Image(systemName: coach.isRunning ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title3)
                    .foregroundStyle(coach.isRunning ? .mint : .primary)
            }
            .accessibilityLabel(coach.isRunning ? "Pause camera" : "Start camera")
        }
    }

    // MARK: - Tint helpers

    private var formScoreTint: Color {
        coach.formScore >= 80 ? .mint : coach.formScore >= 55 ? .fitOrange : .fitRed
    }
    private var confidenceTint: Color {
        coach.poseConfidencePercent >= 70 ? .mint : coach.poseConfidencePercent >= 40 ? .fitOrange : .secondary
    }
}

// MARK: - CameraPermissionGate

private struct CameraPermissionGate: View {
    let message:    String
    let permission: CameraPermission
    let onEnable:   () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))

            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)

            if permission != .authorized {
                Button(action: onEnable) {
                    Label(
                        permission == .denied ? "Open Settings" : "Enable Camera",
                        systemImage: permission == .denied ? "gear" : "lock.open"
                    )
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 26)
                    .padding(.vertical, 13)
                    .background(FitGradient.mint)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .onTapGesture {
                    if permission == .denied,
                       let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    } else {
                        onEnable()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.80))
    }
}
