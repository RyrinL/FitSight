import Vision
import CoreGraphics

// MARK: - Result

/// Full per-frame analysis returned by FormAnalyzer.
struct FormAnalysis {
    let cue: FormCue
    /// Joints to highlight red in the skeleton overlay.
    let issueJoints: Set<VNHumanBodyPoseObservation.JointName>

    static let waiting = FormAnalysis(
        cue: FormCue(text: "Position your full body in frame.", isRepBottom: false,
                     severity: .caution, formScore: 0),
        issueJoints: []
    )
}

// MARK: - Analyzer

enum FormAnalyzer {

    static func analyze(
        exercise: TrackedExercise,
        points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]
    ) -> FormAnalysis {
        switch exercise {
        case .squat:  return analyzeSquat(points)
        case .pushUp: return analyzePushUp(points)
        case .lunge:  return analyzeLunge(points)
        case .plank:  return analyzePlank(points)
        }
    }

    // MARK: - Squat
    // Checks: knee depth angle, knee valgus (cave-in), forward torso lean.

    private static func analyzeSquat(_ pts: Points) -> FormAnalysis {
        guard let lHip   = pt(.leftHip,    pts), let rHip   = pt(.rightHip,   pts),
              let lKnee  = pt(.leftKnee,   pts), let rKnee  = pt(.rightKnee,  pts),
              let lAnkle = pt(.leftAnkle,  pts), let rAnkle = pt(.rightAnkle, pts) else {
            return missing("Show hips, knees, and ankles for squat feedback.")
        }

        let lAngle = angle(lHip.location, lKnee.location, lAnkle.location)
        let rAngle = angle(rHip.location, rKnee.location, rAnkle.location)
        let kneeAngle = (lAngle + rAngle) / 2

        // Valgus: knee closer to hip midline than ankle is — mirror-agnostic.
        let hipMidX    = (lHip.location.x + rHip.location.x) / 2
        let lValgus    = abs(lKnee.location.x - hipMidX) < abs(lAnkle.location.x - hipMidX) - 0.04
        let rValgus    = abs(rKnee.location.x - hipMidX) < abs(rAnkle.location.x - hipMidX) - 0.04
        let kneeValgus = lValgus || rValgus

        // Torso lean: horizontal vs vertical displacement of shoulder from hip.
        let ls = pt(.leftShoulder, pts)?.location
        let rs = pt(.rightShoulder, pts)?.location
        var excessiveLean = false
        if let ls, let rs {
            let sMidX = (ls.x + rs.x) / 2
            let sMidY = (ls.y + rs.y) / 2
            let hMidX = (lHip.location.x + rHip.location.x) / 2
            let hMidY = (lHip.location.y + rHip.location.y) / 2
            let lean  = atan2(abs(sMidX - hMidX), abs(sMidY - hMidY)) * 180 / .pi
            excessiveLean = lean > 22
        }

        let atDepth = kneeAngle < 100

        // Priority: worst error first.
        if kneeValgus {
            var issues: Set<VNHumanBodyPoseObservation.JointName> = []
            if lValgus { issues.insert(.leftKnee);  issues.insert(.leftAnkle) }
            if rValgus { issues.insert(.rightKnee); issues.insert(.rightAnkle) }
            return FormAnalysis(
                cue: FormCue(text: "Knees are caving in — push them out over your toes.",
                             isRepBottom: false, severity: .error,
                             formScore: atDepth ? 45 : 55),
                issueJoints: issues
            )
        }

        if excessiveLean {
            return FormAnalysis(
                cue: FormCue(text: "Keep your back straighter — chest up, weight in your heels.",
                             isRepBottom: atDepth, severity: .caution, formScore: 65),
                issueJoints: [.leftShoulder, .rightShoulder]
            )
        }

        if atDepth {
            return FormAnalysis(
                cue: FormCue(text: "Great depth! Drive up hard through both heels.",
                             isRepBottom: true, severity: .good, formScore: 95),
                issueJoints: []
            )
        }

        if kneeAngle < 130 {
            // Descending — good so far.
            let score = 75 + Int((130 - kneeAngle) / 30 * 15)
            return FormAnalysis(
                cue: FormCue(text: "Good — keep lowering with knees tracking over toes.",
                             isRepBottom: false, severity: .good, formScore: min(90, score)),
                issueJoints: []
            )
        }

        // Standing or just starting descent.
        return FormAnalysis(
            cue: FormCue(text: "Brace your core, then sit hips down and back.",
                         isRepBottom: false, severity: .caution, formScore: 70),
            issueJoints: []
        )
    }

    // MARK: - Push-up
    // Checks: elbow angle (depth), body-line sag/pike, hip deviation.

    private static func analyzePushUp(_ pts: Points) -> FormAnalysis {
        guard let shoulder = best(.leftShoulder, .rightShoulder, pts),
              let elbow    = best(.leftElbow,    .rightElbow,    pts),
              let wrist    = best(.leftWrist,    .rightWrist,    pts),
              let hip      = best(.leftHip,      .rightHip,      pts) else {
            return missing("Show shoulders, elbows, wrists, and hips for push-up feedback.")
        }

        let elbowAngle = angle(shoulder.location, elbow.location, wrist.location)

        // Body-line deviation: how far hip deviates from the shoulder–ankle line.
        var bodyDeviation = 0.0
        var hipAboveLine  = false
        if let ankle = best(.leftAnkle, .rightAnkle, pts) {
            let sY = shoulder.location.y
            let aY = ankle.location.y
            let hY = hip.location.y
            let dx = shoulder.location.x - ankle.location.x
            let t  = dx == 0 ? 0.5 : (hip.location.x - ankle.location.x) / dx
            let expectedHipY = aY + t * (sY - aY)
            bodyDeviation = abs(hY - expectedHipY)
            hipAboveLine  = hY > expectedHipY + 0.08
        }

        let bodySag    = bodyDeviation > 0.1 && !hipAboveLine
        let bodyPike   = hipAboveLine
        let atBottom   = elbowAngle < 95

        if bodySag {
            return FormAnalysis(
                cue: FormCue(text: "Keep shoulders, hips, and ankles in one straight line.",
                             isRepBottom: false, severity: .error, formScore: 50),
                issueJoints: [.leftHip, .rightHip]
            )
        }

        if bodyPike {
            return FormAnalysis(
                cue: FormCue(text: "Drop your hips — you're in a pike. Squeeze your glutes.",
                             isRepBottom: false, severity: .caution, formScore: 60),
                issueJoints: [.leftHip, .rightHip]
            )
        }

        if atBottom {
            return FormAnalysis(
                cue: FormCue(text: "Strong bottom position — press the floor away.",
                             isRepBottom: true, severity: .good, formScore: 95),
                issueJoints: []
            )
        }

        if elbowAngle > 160 {
            return FormAnalysis(
                cue: FormCue(text: "Lower your chest to the floor with control.",
                             isRepBottom: false, severity: .caution, formScore: 70),
                issueJoints: []
            )
        }

        // Mid-range.
        return FormAnalysis(
            cue: FormCue(text: "Good form — elbows at about 45°, core tight.",
                         isRepBottom: false, severity: .good, formScore: 85),
            issueJoints: []
        )
    }

    // MARK: - Lunge
    // Checks: front-knee depth, knee-over-toe forward drift, torso upright.

    private static func analyzeLunge(_ pts: Points) -> FormAnalysis {
        guard let lHip   = pt(.leftHip,   pts), let rHip   = pt(.rightHip,  pts),
              let lKnee  = pt(.leftKnee,  pts), let rKnee  = pt(.rightKnee, pts),
              let lAnkle = pt(.leftAnkle, pts), let rAnkle = pt(.rightAnkle, pts) else {
            return missing("Show both legs for lunge feedback.")
        }

        // Front leg = more bent knee.
        let lAngle = angle(lHip.location, lKnee.location, lAnkle.location)
        let rAngle = angle(rHip.location, rKnee.location, rAnkle.location)
        let (fKnee, fAnkle, fAngle) = lAngle < rAngle
            ? (lKnee.location, lAnkle.location, lAngle)
            : (rKnee.location, rAnkle.location, rAngle)

        // Knee-forward-of-ankle: horizontal distance in normalized space.
        let kneeForward = abs(fKnee.x - fAnkle.x) > 0.14

        // Torso lean.
        let ls = pt(.leftShoulder, pts)?.location
        let rs = pt(.rightShoulder, pts)?.location
        var excessiveLean = false
        if let ls, let rs {
            let sMidX = (ls.x + rs.x) / 2
            let sMidY = (ls.y + rs.y) / 2
            let hMidX = (lHip.location.x + rHip.location.x) / 2
            let hMidY = (lHip.location.y + rHip.location.y) / 2
            let lean  = atan2(abs(sMidX - hMidX), abs(sMidY - hMidY)) * 180 / .pi
            excessiveLean = lean > 20
        }

        let atDepth = fAngle < 110

        if kneeForward {
            return FormAnalysis(
                cue: FormCue(text: "Stack your front knee over the ankle — step out further.",
                             isRepBottom: false, severity: .error, formScore: 50),
                issueJoints: [.leftKnee, .rightKnee]
            )
        }

        if excessiveLean {
            return FormAnalysis(
                cue: FormCue(text: "Keep your back straighter — torso tall through the lunge.",
                             isRepBottom: atDepth, severity: .caution, formScore: 65),
                issueJoints: [.leftShoulder, .rightShoulder]
            )
        }

        if atDepth {
            return FormAnalysis(
                cue: FormCue(text: "Excellent depth — drive through your front heel to rise.",
                             isRepBottom: true, severity: .good, formScore: 95),
                issueJoints: []
            )
        }

        if fAngle > 150 {
            return FormAnalysis(
                cue: FormCue(text: "Lower your hips straight down — keep your torso tall.",
                             isRepBottom: false, severity: .caution, formScore: 70),
                issueJoints: []
            )
        }

        return FormAnalysis(
            cue: FormCue(text: "Good — keep lowering with control.",
                         isRepBottom: false, severity: .good, formScore: 82),
            issueJoints: []
        )
    }

    // MARK: - Plank
    // Checks: hip sag, hip pike (Y-deviation from shoulder–ankle line).

    private static func analyzePlank(_ pts: Points) -> FormAnalysis {
        guard let shoulder = best(.leftShoulder, .rightShoulder, pts),
              let hip      = best(.leftHip,      .rightHip,      pts),
              let ankle    = best(.leftAnkle,    .rightAnkle,    pts) else {
            return missing("Show shoulders, hips, and ankles for plank feedback.")
        }

        // Expected hip Y on the straight shoulder–ankle line.
        let sX = shoulder.location.x, sY = shoulder.location.y
        let aX = ankle.location.x,    aY = ankle.location.y
        let hX = hip.location.x,      hY = hip.location.y
        let dx = sX - aX
        let t  = dx == 0 ? 0.5 : (hX - aX) / dx
        let expectedHipY = aY + t * (sY - aY)
        let deviation    = hY - expectedHipY   // positive = hip above line (pike)

        if deviation < -0.07 {
            // Hip below the line — sagging.
            return FormAnalysis(
                cue: FormCue(text: "Lower your hips — squeeze glutes and draw your navel in.",
                             isRepBottom: false, severity: .error, formScore: 48),
                issueJoints: [.leftHip, .rightHip]
            )
        }

        if deviation > 0.07 {
            // Hip above the line — piking.
            return FormAnalysis(
                cue: FormCue(text: "Drop your hips slightly — you're in a pike position.",
                             isRepBottom: false, severity: .caution, formScore: 62),
                issueJoints: [.leftHip, .rightHip]
            )
        }

        // Small deviation accepted.
        let score = 95 - Int(abs(deviation) / 0.07 * 20)
        return FormAnalysis(
            cue: FormCue(text: "Solid plank line — breathe steadily and hold.",
                         isRepBottom: false, severity: .good, formScore: max(75, score)),
            issueJoints: []
        )
    }

    // MARK: - Utilities

    private typealias Points = [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]

    private static func missing(_ text: String) -> FormAnalysis {
        FormAnalysis(
            cue: FormCue(text: text, isRepBottom: false, severity: .caution, formScore: 0),
            issueJoints: []
        )
    }

    /// Returns the point with name `a` or `b` that has the higher confidence (above 0.25).
    private static func pt(_ name: VNHumanBodyPoseObservation.JointName, _ pts: Points) -> VNRecognizedPoint? {
        guard let p = pts[name], p.confidence > 0.25 else { return nil }
        return p
    }

    private static func best(_ a: VNHumanBodyPoseObservation.JointName,
                              _ b: VNHumanBodyPoseObservation.JointName,
                              _ pts: Points) -> VNRecognizedPoint? {
        [pts[a], pts[b]].compactMap { $0 }.filter { $0.confidence > 0.25 }
                        .max { $0.confidence < $1.confidence }
    }

    /// Angle at vertex `b` formed by rays b→a and b→c, in degrees.
    private static func angle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Double {
        let v1 = CGVector(dx: a.x - b.x, dy: a.y - b.y)
        let v2 = CGVector(dx: c.x - b.x, dy: c.y - b.y)
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let mag = hypot(v1.dx, v1.dy) * hypot(v2.dx, v2.dy)
        guard mag > 1e-6 else { return 180 }
        return Double(acos(min(max(dot / mag, -1.0), 1.0))) * 180 / .pi
    }
}
