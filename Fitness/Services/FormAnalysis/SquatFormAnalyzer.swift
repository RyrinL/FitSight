import Vision
import Foundation

// MARK: - Concrete rules
//
// Each rule is a small, focused struct that implements SquatRule.
// Rules only import what they need (JointAngleCalculator), keeping
// Vision types out of the analysis layer.

// MARK: KneeValgusRule
//
// Detects knee cave-in: knees collapsing toward the midline while ankles remain wider.
//
// Algorithm:
//   Hip midline X = (leftHip.x + rightHip.x) / 2
//   Valgus on a side when |knee.x - midline| + 0.04 < |ankle.x - midline|
//   The 0.04 tolerance avoids false positives from slight natural varus/valgus alignment.

struct KneeValgusRule: SquatRule {

    func evaluate(joints: SquatJoints) -> SquatFeedback? {
        let hipMidX = JointAngleCalculator.midpoint(joints.leftHip, joints.rightHip).x

        let lValgus = abs(joints.leftKnee.x  - hipMidX) < abs(joints.leftAnkle.x  - hipMidX) - 0.04
        let rValgus = abs(joints.rightKnee.x - hipMidX) < abs(joints.rightAnkle.x - hipMidX) - 0.04

        guard lValgus || rValgus else { return nil }

        var issues: Set<VNHumanBodyPoseObservation.JointName> = []
        if lValgus { issues.insert(.leftKnee);  issues.insert(.leftAnkle) }
        if rValgus { issues.insert(.rightKnee); issues.insert(.rightAnkle) }

        return SquatFeedback(
            message:     "Knees are caving in — drive them out over your toes.",
            severity:    .error,
            formScore:   45,
            isAtDepth:   false,
            issueJoints: issues
        )
    }
}

// MARK: TorsoLeanRule
//
// Flags excessive forward lean of the torso using the shoulder-to-hip angle.
// Threshold: 22° from vertical — beyond this, the lower back is under significant stress.
// Requires shoulder joints; silently passes if they are not visible.

struct TorsoLeanRule: SquatRule {

    private let threshold = 22.0   // degrees from vertical

    func evaluate(joints: SquatJoints) -> SquatFeedback? {
        guard let ls = joints.leftShoulder, let rs = joints.rightShoulder else {
            return nil   // can't measure lean without shoulders — skip silently
        }
        let shoulderMid = JointAngleCalculator.midpoint(ls, rs)
        let hipMid      = JointAngleCalculator.midpoint(joints.leftHip, joints.rightHip)
        let lean        = JointAngleCalculator.torsoLean(shoulderMid: shoulderMid,
                                                          hipMid: hipMid)
        guard lean > threshold else { return nil }

        return SquatFeedback(
            message:     "Keep your back straighter — chest up, weight through your heels.",
            severity:    .caution,
            formScore:   65,
            isAtDepth:   false,
            issueJoints: [.leftShoulder, .rightShoulder]
        )
    }
}

// MARK: KneeDepthRule
//
// Provides progression feedback through the squat's range of motion.
// Depth thresholds (average of left + right knee angle):
//   angle < 100° → at or below parallel (good depth, count rep bottom)
//   100–130°     → descending well (encourage to keep lowering)
//   > 130°       → shallow / standing (prompt to sit deeper)

struct KneeDepthRule: SquatRule {

    func evaluate(joints: SquatJoints) -> SquatFeedback? {
        let lAngle = JointAngleCalculator.kneeAngle(hip:   joints.leftHip,
                                                     knee:  joints.leftKnee,
                                                     ankle: joints.leftAnkle)
        let rAngle = JointAngleCalculator.kneeAngle(hip:   joints.rightHip,
                                                     knee:  joints.rightKnee,
                                                     ankle: joints.rightAnkle)
        let avg = (lAngle + rAngle) / 2

        switch avg {
        case ..<100:
            // At or below parallel — this is the rep bottom.
            return SquatFeedback(
                message:     "Great depth! Drive through both heels to rise.",
                severity:    .good,
                formScore:   95,
                isAtDepth:   true,
                issueJoints: []
            )
        case 100..<130:
            // Descending — good progress.
            let score = 75 + Int((130 - avg) / 30 * 15)   // interpolate 75→90
            return SquatFeedback(
                message:     "Good — keep lowering with knees tracking over toes.",
                severity:    .good,
                formScore:   min(90, score),
                isAtDepth:   false,
                issueJoints: []
            )
        default:
            // Standing or just beginning descent.
            return SquatFeedback(
                message:     "Squat deeper — aim for thighs parallel to the floor.",
                severity:    .caution,
                formScore:   60,
                isAtDepth:   false,
                issueJoints: []
            )
        }
    }
}

// MARK: - SquatFormAnalyzer
//
// The public entry point for squat analysis.
// Composes the three rules in priority order and delegates to RuleEngine.
//
// Rule priority rationale:
//   1. KneeValgusRule  — safety-critical; must fix before chasing depth
//   2. TorsoLeanRule   — technique cue; correct after valgus resolved
//   3. KneeDepthRule   — progression feedback; shown when form is otherwise good
//
// Static properties: rules share no mutable state, so a single instance
// per rule type (allocated once at class load time) is fine.

enum SquatFormAnalyzer {

    private static let rules: [any SquatRule] = [
        KneeValgusRule(),
        TorsoLeanRule(),
        KneeDepthRule(),
    ]

    /// Analyses a single frame's squat joints and returns the highest-priority feedback.
    /// - Returns: A `SquatFeedback` value — never nil (falls back to "brace your core").
    static func analyze(joints: SquatJoints) -> SquatFeedback {
        RuleEngine.evaluate(
            joints:   joints,
            rules:    rules,
            fallback: SquatFeedback(
                message:     "Brace your core and sit your hips down and back.",
                severity:    .caution,
                formScore:   70,
                isAtDepth:   false,
                issueJoints: []
            )
        )
    }
}
