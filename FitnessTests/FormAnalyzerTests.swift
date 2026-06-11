import XCTest
import Vision
@testable import Fitness

// Allow XCTAssertEqual comparisons on FormSeverity
extension FormSeverity: Equatable {
    public static func == (lhs: FormSeverity, rhs: FormSeverity) -> Bool {
        switch (lhs, rhs) {
        case (.good, .good), (.caution, .caution), (.error, .error): return true
        default: return false
        }
    }
}

final class FormAnalyzerTests: XCTestCase {

    // MARK: - Mock VNRecognizedPoint

    // Subclass that exposes a mutable confidence so tests can control the filter.
    private final class MockPoint: VNRecognizedPoint {
        var mockedConfidence: VNConfidence = 0.99
        override var confidence: VNConfidence { mockedConfidence }
    }

    /// Creates a point at normalized coordinates with high confidence (default 0.99).
    private func pt(_ x: Double, _ y: Double, conf: VNConfidence = 0.99) -> VNRecognizedPoint {
        let m = try! MockPoint(x: x, y: y)
        m.mockedConfidence = conf
        return m
    }

    // MARK: - Squat

    func test_squat_goodDepth_severityGood() {
        // Knee angle ≈ 90° at both sides → atDepth, no valgus, no lean
        // lHip→lKnee vector = (0, 0.3), lKnee→lAnkle = (0.3, 0) → angle 90°
        let joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] = [
            .leftHip:       pt(0.3, 0.8),
            .leftKnee:      pt(0.3, 0.5),
            .leftAnkle:     pt(0.6, 0.5),
            .rightHip:      pt(0.7, 0.8),
            .rightKnee:     pt(0.7, 0.5),
            .rightAnkle:    pt(0.4, 0.5),
            .leftShoulder:  pt(0.3, 0.9),
            .rightShoulder: pt(0.7, 0.9),
        ]
        let result = FormAnalyzer.analyze(exercise: .squat, points: joints)
        XCTAssertEqual(result.cue.severity, .good)
        XCTAssertTrue(result.cue.isRepBottom)
        XCTAssertEqual(result.cue.formScore, 95)
        XCTAssertTrue(result.issueJoints.isEmpty)
    }

    func test_squat_valgusKnees_severityError() {
        // Both knees collapse to x=0.5 (hip midline), ankles are wider
        // |knee−midline| = 0, |ankle−midline| = 0.2 → 0 < 0.16 → lValgus
        let joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] = [
            .leftHip:    pt(0.3, 0.8),
            .leftKnee:   pt(0.5, 0.5),
            .leftAnkle:  pt(0.3, 0.3),
            .rightHip:   pt(0.7, 0.8),
            .rightKnee:  pt(0.5, 0.5),
            .rightAnkle: pt(0.7, 0.3),
        ]
        let result = FormAnalyzer.analyze(exercise: .squat, points: joints)
        XCTAssertEqual(result.cue.severity, .error)
        XCTAssertTrue(result.cue.text.localizedCaseInsensitiveContains("caving"))
        XCTAssertFalse(result.issueJoints.isEmpty)
    }

    func test_squat_excessiveLean_severityCaution() {
        // Shoulder midpoint at (0.3, 0.4), hip midpoint at (0.5, 0.7)
        // lean = atan2(|0.3-0.5|, |0.4-0.7|) = atan2(0.2, 0.3) ≈ 33.7° > 22°
        let joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] = [
            .leftHip:       pt(0.3, 0.7),
            .leftKnee:      pt(0.3, 0.5),
            .leftAnkle:     pt(0.3, 0.3),
            .rightHip:      pt(0.7, 0.7),
            .rightKnee:     pt(0.7, 0.5),
            .rightAnkle:    pt(0.7, 0.3),
            .leftShoulder:  pt(0.1, 0.4),
            .rightShoulder: pt(0.5, 0.4),
        ]
        let result = FormAnalyzer.analyze(exercise: .squat, points: joints)
        XCTAssertEqual(result.cue.severity, .caution)
        XCTAssertTrue(result.cue.text.localizedCaseInsensitiveContains("back") ||
                      result.cue.text.localizedCaseInsensitiveContains("straighter"))
    }

    func test_squat_missingJoints_returnsZeroScore() {
        let result = FormAnalyzer.analyze(exercise: .squat, points: [:])
        XCTAssertEqual(result.cue.formScore, 0)
        XCTAssertFalse(result.cue.isRepBottom)
    }

    func test_squat_lowConfidencePoints_treatedAsMissing() {
        // All points below the 0.25 confidence threshold → same as missing
        let joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] = [
            .leftHip:    pt(0.3, 0.8, conf: 0.1),
            .leftKnee:   pt(0.3, 0.5, conf: 0.1),
            .leftAnkle:  pt(0.6, 0.5, conf: 0.1),
            .rightHip:   pt(0.7, 0.8, conf: 0.1),
            .rightKnee:  pt(0.7, 0.5, conf: 0.1),
            .rightAnkle: pt(0.4, 0.5, conf: 0.1),
        ]
        let result = FormAnalyzer.analyze(exercise: .squat, points: joints)
        XCTAssertEqual(result.cue.formScore, 0)
    }

    // MARK: - Push-up

    func test_pushUp_goodBottom_severityGood() {
        // Elbow angle = 90° (< 95° → atBottom), hip on shoulder–ankle line
        // shoulder(0.5,0.8)→elbow(0.5,0.5) v1=(0,0.3); elbow→wrist(0.8,0.5) v2=(0.3,0) → 90°
        // dx=0 → t=0.5; expectedHipY = 0.1+0.5*(0.8-0.1) = 0.45; hip is at 0.45
        let joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] = [
            .leftShoulder: pt(0.5, 0.8),
            .leftElbow:    pt(0.5, 0.5),
            .leftWrist:    pt(0.8, 0.5),
            .leftHip:      pt(0.5, 0.45),
            .leftAnkle:    pt(0.5, 0.1),
        ]
        let result = FormAnalyzer.analyze(exercise: .pushUp, points: joints)
        XCTAssertEqual(result.cue.severity, .good)
        XCTAssertTrue(result.cue.isRepBottom)
    }

    func test_pushUp_bodySag_severityError() {
        // Hip well below shoulder–ankle line: expected 0.45, actual 0.2 → deviation 0.25 > 0.1
        let joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] = [
            .leftShoulder: pt(0.5, 0.8),
            .leftElbow:    pt(0.3, 0.65),
            .leftWrist:    pt(0.2, 0.5),
            .leftHip:      pt(0.5, 0.2),
            .leftAnkle:    pt(0.5, 0.1),
        ]
        let result = FormAnalyzer.analyze(exercise: .pushUp, points: joints)
        XCTAssertEqual(result.cue.severity, .error)
        XCTAssertTrue(result.cue.text.localizedCaseInsensitiveContains("line") ||
                      result.cue.text.localizedCaseInsensitiveContains("straight"))
    }

    func test_pushUp_bodyPike_severityCaution() {
        // Hip well above shoulder–ankle line: 0.65 > 0.45+0.08=0.53 → hipAboveLine
        let joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] = [
            .leftShoulder: pt(0.5, 0.8),
            .leftElbow:    pt(0.3, 0.65),
            .leftWrist:    pt(0.2, 0.5),
            .leftHip:      pt(0.5, 0.65),
            .leftAnkle:    pt(0.5, 0.1),
        ]
        let result = FormAnalyzer.analyze(exercise: .pushUp, points: joints)
        XCTAssertEqual(result.cue.severity, .caution)
        XCTAssertTrue(result.cue.text.localizedCaseInsensitiveContains("pike"))
    }

    func test_pushUp_missingJoints_returnsZeroScore() {
        let result = FormAnalyzer.analyze(exercise: .pushUp, points: [:])
        XCTAssertEqual(result.cue.formScore, 0)
    }

    // MARK: - Lunge

    func test_lunge_goodDepth_severityGood() {
        // lHip(0.5,0.55)→lKnee(0.7,0.5)→lAnkle(0.7,0.1):
        // v1=(-0.2,0.05), v2=(0,-0.4), cos≈-0.243 → angle≈104° < 110° → atDepth
        // |lKnee.x - lAnkle.x| = 0 → no kneeForward
        // rAngle = 180° (back leg straight) → front=left
        let joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] = [
            .leftHip:       pt(0.5, 0.55),
            .leftKnee:      pt(0.7, 0.5),
            .leftAnkle:     pt(0.7, 0.1),
            .rightHip:      pt(0.3, 0.55),
            .rightKnee:     pt(0.3, 0.5),
            .rightAnkle:    pt(0.3, 0.1),
            .leftShoulder:  pt(0.4, 0.9),
            .rightShoulder: pt(0.6, 0.9),
        ]
        let result = FormAnalyzer.analyze(exercise: .lunge, points: joints)
        XCTAssertEqual(result.cue.severity, .good)
        XCTAssertTrue(result.cue.isRepBottom)
    }

    func test_lunge_kneeForward_severityError() {
        // Front knee 0.2 units ahead of front ankle → |0.7-0.5| = 0.2 > 0.14
        let joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] = [
            .leftHip:    pt(0.3, 0.8),
            .leftKnee:   pt(0.7, 0.5),
            .leftAnkle:  pt(0.5, 0.1),
            .rightHip:   pt(0.7, 0.8),
            .rightKnee:  pt(0.65, 0.5),
            .rightAnkle: pt(0.6, 0.1),
        ]
        let result = FormAnalyzer.analyze(exercise: .lunge, points: joints)
        XCTAssertEqual(result.cue.severity, .error)
        XCTAssertTrue(result.cue.text.localizedCaseInsensitiveContains("ankle") ||
                      result.cue.text.localizedCaseInsensitiveContains("knee"))
    }

    func test_lunge_missingJoints_returnsZeroScore() {
        let result = FormAnalyzer.analyze(exercise: .lunge, points: [:])
        XCTAssertEqual(result.cue.formScore, 0)
    }

    // MARK: - Plank

    func test_plank_goodAlignment_severityGood() {
        // Horizontal body: shoulder(0.8,0.5), ankle(0.2,0.5), hip(0.5,0.5)
        // t=0.5; expectedHipY = 0.5+0.5*(0.5-0.5) = 0.5; deviation = 0
        let joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] = [
            .leftShoulder: pt(0.8, 0.5),
            .leftHip:      pt(0.5, 0.5),
            .leftAnkle:    pt(0.2, 0.5),
        ]
        let result = FormAnalyzer.analyze(exercise: .plank, points: joints)
        XCTAssertEqual(result.cue.severity, .good)
        XCTAssertGreaterThanOrEqual(result.cue.formScore, 75)
    }

    func test_plank_hipSag_severityError() {
        // Hip at y=0.3, expected y=0.5; deviation = -0.2 < -0.07 → sag
        let joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] = [
            .leftShoulder: pt(0.8, 0.5),
            .leftHip:      pt(0.5, 0.3),
            .leftAnkle:    pt(0.2, 0.5),
        ]
        let result = FormAnalyzer.analyze(exercise: .plank, points: joints)
        XCTAssertEqual(result.cue.severity, .error)
        XCTAssertTrue(result.cue.text.localizedCaseInsensitiveContains("squeeze") ||
                      result.cue.text.localizedCaseInsensitiveContains("lower") ||
                      result.cue.text.localizedCaseInsensitiveContains("navel"))
    }

    func test_plank_hipPike_severityCaution() {
        // Hip at y=0.7, expected y=0.5; deviation = +0.2 > +0.07 → pike
        let joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] = [
            .leftShoulder: pt(0.8, 0.5),
            .leftHip:      pt(0.5, 0.7),
            .leftAnkle:    pt(0.2, 0.5),
        ]
        let result = FormAnalyzer.analyze(exercise: .plank, points: joints)
        XCTAssertEqual(result.cue.severity, .caution)
        XCTAssertTrue(result.cue.text.localizedCaseInsensitiveContains("pike"))
    }

    func test_plank_missingJoints_returnsZeroScore() {
        let result = FormAnalyzer.analyze(exercise: .plank, points: [:])
        XCTAssertEqual(result.cue.formScore, 0)
    }

    // MARK: - FormAnalysis.waiting sentinel

    func test_formAnalysis_waiting_hasZeroScore() {
        XCTAssertEqual(FormAnalysis.waiting.cue.formScore, 0)
        XCTAssertFalse(FormAnalysis.waiting.cue.isRepBottom)
        XCTAssertTrue(FormAnalysis.waiting.issueJoints.isEmpty)
    }
}
