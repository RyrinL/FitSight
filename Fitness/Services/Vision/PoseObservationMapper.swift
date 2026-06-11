import Vision
import CoreGraphics

// MARK: - SquatJoints
//
// A strongly-typed, Sendable snapshot of the six mandatory squat joints
// plus optional shoulder joints for torso-lean analysis.
//
// All coordinates are in Vision normalised space:
//   (0,0) = bottom-left corner of the frame
//   (1,1) = top-right corner of the frame
//
// Sendable: the struct contains only CGPoint (value type) and optional CGPoint,
// making it safe to pass across actor boundaries without copies.

struct SquatJoints: Sendable {
    // Mandatory — mapper returns nil if any of these fall below the confidence threshold.
    let leftHip:       CGPoint
    let leftKnee:      CGPoint
    let leftAnkle:     CGPoint
    let rightHip:      CGPoint
    let rightKnee:     CGPoint
    let rightAnkle:    CGPoint

    // Optional — used for torso-lean analysis. Nil when shoulder is occluded.
    let leftShoulder:  CGPoint?
    let rightShoulder: CGPoint?
}

// MARK: - PoseObservationMapper
//
// Converts a raw VNHumanBodyPoseObservation (Vision-opaque) into typed domain
// objects that the rest of the app can use without importing Vision.
//
// Confidence threshold rationale:
//   0.25 is conservative — it accepts partially-occluded joints (common in
//   full-frame squat shots) while rejecting random low-confidence detections.
//   Raising to 0.5 gives cleaner data but fails more often at the edge of frame.

enum PoseObservationMapper {

    static let confidenceThreshold: VNConfidence = 0.25

    // MARK: - SquatJoints extraction

    /// Extracts mandatory squat joints from the observation.
    /// Returns nil when any of the six key joints is below the confidence threshold —
    /// the analyzer needs all of them to produce meaningful feedback.
    static func squatJoints(from obs: VNHumanBodyPoseObservation) -> SquatJoints? {
        guard
            let lHip   = cgPoint(.leftHip,    obs),
            let lKnee  = cgPoint(.leftKnee,   obs),
            let lAnkle = cgPoint(.leftAnkle,  obs),
            let rHip   = cgPoint(.rightHip,   obs),
            let rKnee  = cgPoint(.rightKnee,  obs),
            let rAnkle = cgPoint(.rightAnkle, obs)
        else { return nil }

        return SquatJoints(
            leftHip:       lHip,
            leftKnee:      lKnee,
            leftAnkle:     lAnkle,
            rightHip:      rHip,
            rightKnee:     rKnee,
            rightAnkle:    rAnkle,
            leftShoulder:  cgPoint(.leftShoulder,  obs),
            rightShoulder: cgPoint(.rightShoulder, obs)
        )
    }

    // MARK: - Display points (skeleton overlay)

    /// Returns all joints above the confidence threshold, converted to CGPoint.
    /// Used by SkeletonOverlayView to render the live skeleton on the camera preview.
    static func displayPoints(
        from obs: VNHumanBodyPoseObservation
    ) -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
        guard let all = try? obs.recognizedPoints(.all) else { return [:] }
        return all.reduce(into: [:]) { dict, pair in
            guard pair.value.confidence > confidenceThreshold else { return }
            dict[pair.key] = CGPoint(x: Double(pair.value.location.x),
                                     y: Double(pair.value.location.y))
        }
    }

    // MARK: - Confidence score

    /// Average confidence of all visible joints (above threshold), as a 0–100 integer.
    /// Displayed in the HUD as the "CONF" gauge.
    static func averageConfidencePercent(from obs: VNHumanBodyPoseObservation) -> Int {
        guard let all = try? obs.recognizedPoints(.all) else { return 0 }
        let visible = all.values.filter { $0.confidence > confidenceThreshold }
        guard !visible.isEmpty else { return 0 }
        let sum = visible.reduce(0.0) { $0 + Double($1.confidence) }
        return Int((sum / Double(visible.count)) * 100)
    }

    // MARK: - Private helpers

    /// Returns the CGPoint for `joint` if its confidence exceeds the threshold, else nil.
    private static func cgPoint(_ joint: VNHumanBodyPoseObservation.JointName,
                                 _ obs: VNHumanBodyPoseObservation) -> CGPoint? {
        guard
            let all = try? obs.recognizedPoints(.all),
            let p   = all[joint],
            p.confidence > confidenceThreshold
        else { return nil }
        return CGPoint(x: Double(p.location.x), y: Double(p.location.y))
    }
}
