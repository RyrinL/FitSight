import Foundation

// MARK: - SquatRule
//
// A single, self-contained form check for the squat exercise.
//
// Rules are evaluated in priority order by RuleEngine.evaluate().
// A rule returns:
//   • non-nil SquatFeedback → issue detected; evaluation stops (fail-fast)
//   • nil                  → this rule passes; move to the next rule
//
// This protocol-oriented design makes it trivial to add or reorder rules
// (e.g. add a heel-rise rule) without touching the core evaluation loop.

protocol SquatRule {
    func evaluate(joints: SquatJoints) -> SquatFeedback?
}

// MARK: - RuleEngine

/// Runs a prioritised list of `SquatRule` checks against a single frame's joints
/// and returns the first failing rule's feedback, or a caller-supplied fallback.
///
/// Example priority order (highest → lowest):
///   1. KneeValgusRule   (safety-critical — must fix first)
///   2. TorsoLeanRule    (caution — correct after valgus is resolved)
///   3. KneeDepthRule    (progress feedback — descent, depth, standing)
///
/// By returning on the first failure, the user gets ONE clear cue per frame
/// rather than a confusing list of simultaneous corrections.

enum RuleEngine {

    /// - Parameters:
    ///   - joints:   The extracted, confidence-filtered squat joints for this frame.
    ///   - rules:    Ordered array of rules to evaluate (highest priority first).
    ///   - fallback: Returned when all rules pass — typically a "brace your core" cue.
    /// - Returns: The first non-nil rule result, or `fallback` if all rules pass.
    static func evaluate(joints: SquatJoints,
                         rules: [any SquatRule],
                         fallback: SquatFeedback) -> SquatFeedback {
        for rule in rules {
            if let result = rule.evaluate(joints: joints) {
                return result
            }
        }
        return fallback
    }
}
