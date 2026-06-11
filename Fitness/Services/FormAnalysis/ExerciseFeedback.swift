import Vision
import Foundation

// MARK: - SquatFeedback
//
// The output produced by a single frame's squat form analysis.
// Sendable: all stored properties are value types (String, enum, Int, Bool, Set<JointName>)
// so this struct can cross actor/thread boundaries without copying issues.
//
// The ViewModel holds a rolling buffer of `formScore` values and averages them
// for a smoother display. `isAtDepth` drives rep counting in the ViewModel.

struct SquatFeedback: Sendable {

    // MARK: - Properties

    /// Human-readable coaching cue shown to the user. Kept short (<60 chars)
    /// so it fits in the feedback card on all iPhone screen sizes.
    let message: String

    /// Severity drives the feedback-card colour:
    ///   .good    → mint green  (correct form or good progress)
    ///   .caution → orange      (improvable, non-critical issue)
    ///   .error   → red         (safety-critical, stop and correct)
    let severity: FormSeverity

    /// Raw per-frame form quality score 0–100.
    /// The ViewModel smooths this over an 8-frame rolling window before display.
    let formScore: Int

    /// True when the user is at or below parallel (knee angle < 100°).
    /// Used by the ViewModel for bottom→top rep-counting transitions.
    let isAtDepth: Bool

    /// Joints to highlight red in the skeleton overlay. Empty when form is good.
    let issueJoints: Set<VNHumanBodyPoseObservation.JointName>

    // MARK: - Sentinels

    /// Shown when mandatory joints are visible but the mapper could not extract them
    /// (e.g. all below confidence threshold).
    static let notVisible = SquatFeedback(
        message:     "Show your full body — hips, knees, and ankles must be visible.",
        severity:    .caution,
        formScore:   0,
        isAtDepth:   false,
        issueJoints: []
    )

    /// Shown when Vision finds no person in the frame at all.
    static let noPose = SquatFeedback(
        message:     "Move back until your full body is visible.",
        severity:    .caution,
        formScore:   0,
        isAtDepth:   false,
        issueJoints: []
    )

    /// Shown before the session starts.
    static let waiting = SquatFeedback(
        message:     "Position your full body in frame.",
        severity:    .caution,
        formScore:   0,
        isAtDepth:   false,
        issueJoints: []
    )
}
