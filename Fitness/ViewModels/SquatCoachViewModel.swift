import AVFoundation
import Vision
import Combine
import Foundation

// MARK: - SquatPoseActor
//
// Private actor that owns all mutable per-frame state.
// Running on its own executor means every update is serialised without locks,
// and the main thread is never blocked waiting for smoothing or scoring math.
//
// State owned here:
//   smoothed      — EMA-smoothed joint positions for the skeleton overlay
//   scoreBuffer   — rolling window of raw form scores → averaged for display
//   lastFeedback* — debounce tracking so the UI text doesn't flicker every frame
//   wasInRepBottom — state machine for bottom→top rep transition detection

private actor SquatPoseActor {

    // MARK: - Mutable state

    private var smoothed:         [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    private var scoreBuffer:      [Int]   = []
    private var lastFeedbackText  = ""
    private var lastFeedbackTime  = Date.distantPast
    private var wasInRepBottom    = false

    // MARK: - Constants

    private static let smoothAlpha:      Double        = 0.75   // EMA weight for new frame
    private static let scoreBufferSize:  Int           = 8      // frames to average
    private static let debounceInterval: TimeInterval  = 0.45   // seconds between UI text changes

    // MARK: - FrameResult

    /// Sendable result crossing the actor boundary → MainActor for UI application.
    struct FrameResult: Sendable {
        let displayPoints:        [VNHumanBodyPoseObservation.JointName: CGPoint]
        let issueJoints:          Set<VNHumanBodyPoseObservation.JointName>
        let confPercent:          Int
        let formScore:            Int            // smoothed average
        let feedbackText:         String
        let feedbackSeverity:     FormSeverity
        let shouldUpdateFeedback: Bool           // false → debounced, keep current UI text
        let didCompleteRep:       Bool
    }

    // MARK: - Process frame

    func process(feedback: SquatFeedback,
                 displayPoints: [VNHumanBodyPoseObservation.JointName: CGPoint],
                 confPercent: Int) -> FrameResult {

        // 1. EMA smoothing of skeleton joints.
        //    New position = α × raw + (1-α) × previous.
        //    α=0.5 gives a 50/50 blend, which removes single-frame jitter
        //    while still tracking fast movement accurately.
        for (name, raw) in displayPoints {
            if let prev = smoothed[name] {
                smoothed[name] = CGPoint(
                    x: Self.smoothAlpha * raw.x + (1 - Self.smoothAlpha) * prev.x,
                    y: Self.smoothAlpha * raw.y + (1 - Self.smoothAlpha) * prev.y
                )
            } else {
                smoothed[name] = raw   // first frame for this joint
            }
        }

        // 2. Rolling form score.
        scoreBuffer.append(feedback.formScore)
        if scoreBuffer.count > Self.scoreBufferSize { scoreBuffer.removeFirst() }
        let avgScore = scoreBuffer.reduce(0, +) / max(scoreBuffer.count, 1)

        // 3. Feedback debounce.
        //    Error-severity cues bypass the cooldown so critical cues (e.g. "knees
        //    caving in") are surfaced immediately — safety over smoothness.
        let text        = feedback.message
        let isError     = feedback.severity == .error
        let textChanged = text != lastFeedbackText
        let cooled      = Date().timeIntervalSince(lastFeedbackTime) >= Self.debounceInterval
        let shouldUpdate = textChanged && (isError || cooled)
        if shouldUpdate {
            lastFeedbackText = text
            lastFeedbackTime = Date()
        }

        // 4. Rep counting state machine.
        //    A rep is counted when the user leaves the bottom position (isAtDepth → false).
        //    This avoids double-counting if they pause at the bottom.
        var didCompleteRep = false
        if feedback.isAtDepth, !wasInRepBottom {
            wasInRepBottom = true
        } else if !feedback.isAtDepth, wasInRepBottom {
            wasInRepBottom = false
            didCompleteRep = true
        }

        return FrameResult(
            displayPoints:        smoothed,
            issueJoints:          feedback.issueJoints,
            confPercent:          confPercent,
            formScore:            avgScore,
            feedbackText:         text,
            feedbackSeverity:     feedback.severity,
            shouldUpdateFeedback: shouldUpdate,
            didCompleteRep:       didCompleteRep
        )
    }

    // MARK: - Reset

    func resetSession() {
        smoothed         = [:]
        scoreBuffer      = []
        lastFeedbackText = ""
        lastFeedbackTime = .distantPast
        wasInRepBottom   = false
    }

    func clearSmoothed() {
        smoothed = [:]
    }
}

// MARK: - SquatCoachViewModel
//
// @MainActor ObservableObject that orchestrates the full pipeline:
//
//   CameraManager ──starts──► FrameProcessor ──videoQueue──►
//   PoseDetector ──obs──► PoseObservationMapper ──joints──►
//   SquatFormAnalyzer ──feedback──► SquatPoseActor ──FrameResult──►
//   MainActor (apply) ──► @Published state ──► SwiftUI

@MainActor
final class SquatCoachViewModel: ObservableObject {

    // MARK: - Published state

    @Published var feedback:          String      = SquatFeedback.waiting.message
    @Published var feedbackSeverity:  FormSeverity = .caution
    @Published var formScore:         Int          = 0
    @Published var repCount:          Int          = 0
    @Published var confPercent:       Int          = 0
    @Published var poseDisplayPoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    @Published var issueJoints:       Set<VNHumanBodyPoseObservation.JointName>       = []

    // Permission and running state forwarded from CameraManager.
    @Published private(set) var permission:      CameraPermission = .unknown
    @Published private(set) var isRunning:       Bool             = false
    @Published private(set) var activeBackend:   PoseBackend      = .vision

    // MARK: - Services

    /// Exposed so FormCoachView can bind CameraPreviewView to the session.
    let cameraManager:  CameraManager
    private let frameProcessor: FrameProcessor

    private let poseActor = SquatPoseActor()

    // Combine subscriptions for forwarding CameraManager published values.
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        cameraManager  = CameraManager()
        frameProcessor = FrameProcessor()

        // Forward camera state so the view only needs to observe this ViewModel.
        cameraManager.$permission
            .assign(to: &$permission)
        cameraManager.$isRunning
            .assign(to: &$isRunning)

        wireFrameCallbacks()
    }

    // MARK: - Public API

    /// Requests camera access; starts the session immediately if already granted.
    func requestAccess() {
        cameraManager.requestAccess { [weak self] in
            self?.startSession()
        }
    }

    func startSession() {
        cameraManager.start(frameProcessor: frameProcessor)
    }

    func stopSession() {
        cameraManager.stop()
    }

    func resetReps() {
        repCount = 0
        let actor = poseActor
        Task { await actor.resetSession() }
    }

    var permissionMessage: String { cameraManager.permissionMessage }

    // MARK: - Frame callback wiring
    //
    // Called from init() (on MainActor), so `poseActor` is safe to capture here.
    // The closures run on videoQueue (non-isolated); `actor` is Sendable so it
    // crosses the Task boundary without a MainActor hop.

    private func wireFrameCallbacks() {
        let actor = poseActor   // capture while on MainActor; actors are Sendable

        // Unified callback — works for both Vision and MoveNet backends.
        frameProcessor.onPoseResult = { [weak self, actor] result in
            // Surface which backend produced this frame (for the debug badge).
            Task { @MainActor [weak self] in self?.activeBackend = result.backend }
            // Runs on videoQueue. All values are already Sendable.
            let displayPts = result.displayPoints
            let confPct    = result.confPercent

            if let joints = result.squatJoints {
                let sqFeedback = SquatFormAnalyzer.analyze(joints: joints)

                Task { [weak self, actor] in
                    let frameResult = await actor.process(
                        feedback:      sqFeedback,
                        displayPoints: displayPts,
                        confPercent:   confPct
                    )
                    await MainActor.run { [weak self] in self?.apply(frameResult) }
                }
            } else {
                // Partial body visible — show skeleton but prompt for better framing.
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    poseDisplayPoints = displayPts
                    confPercent       = confPct
                    if feedback != SquatFeedback.notVisible.message {
                        feedback         = SquatFeedback.notVisible.message
                        feedbackSeverity = .caution
                    }
                }
            }
        }

        frameProcessor.onPoseLost = { [weak self] in
            Task { @MainActor [weak self] in self?.clearPose() }
        }
    }

    // MARK: - Apply result to UI

    private func apply(_ result: SquatPoseActor.FrameResult) {
        poseDisplayPoints = result.displayPoints
        issueJoints       = result.issueJoints
        confPercent       = result.confPercent
        formScore         = result.formScore

        if result.shouldUpdateFeedback {
            feedback        = result.feedbackText
            feedbackSeverity = result.feedbackSeverity
        }

        if result.didCompleteRep {
            repCount += 1
            FitHaptic.impact(.medium)   // tactile confirmation of counted rep
        }
    }

    private func clearPose() {
        poseDisplayPoints = [:]
        issueJoints       = []
        confPercent       = 0
        let actor = poseActor
        Task { await actor.clearSmoothed() }

        guard feedback != SquatFeedback.noPose.message else { return }
        feedback        = SquatFeedback.noPose.message
        feedbackSeverity = .caution
    }
}
