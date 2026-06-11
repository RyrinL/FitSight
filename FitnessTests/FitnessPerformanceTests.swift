import XCTest
import Vision
@testable import Fitness

/// Performance tests verify that pose analysis stays within the 33ms/frame budget
/// required for real-time camera feedback at 30 FPS.
final class FitnessPerformanceTests: XCTestCase {

    // MARK: - Shared MockPoint

    private final class MockPoint: VNRecognizedPoint {
        var mockedConfidence: VNConfidence = 0.99
        override var confidence: VNConfidence { mockedConfidence }
    }

    private func pt(_ x: Double, _ y: Double) -> VNRecognizedPoint {
        let m = try! MockPoint(x: x, y: y)
        return m
    }

    // MARK: - Point sets

    private var squatPoints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] {
        [
            .leftHip:       pt(0.3, 0.8), .leftKnee:  pt(0.3, 0.5), .leftAnkle:  pt(0.6, 0.5),
            .rightHip:      pt(0.7, 0.8), .rightKnee: pt(0.7, 0.5), .rightAnkle: pt(0.4, 0.5),
            .leftShoulder:  pt(0.3, 0.9), .rightShoulder: pt(0.7, 0.9),
        ]
    }

    private var pushUpPoints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] {
        [
            .leftShoulder: pt(0.5, 0.8), .leftElbow: pt(0.5, 0.5),
            .leftWrist:    pt(0.8, 0.5), .leftHip:   pt(0.5, 0.45), .leftAnkle: pt(0.5, 0.1),
        ]
    }

    private var lungePoints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] {
        [
            .leftHip:  pt(0.5, 0.55), .leftKnee:  pt(0.7, 0.5), .leftAnkle:  pt(0.7, 0.1),
            .rightHip: pt(0.3, 0.55), .rightKnee: pt(0.3, 0.5), .rightAnkle: pt(0.3, 0.1),
        ]
    }

    private var plankPoints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] {
        [.leftShoulder: pt(0.8, 0.5), .leftHip: pt(0.5, 0.5), .leftAnkle: pt(0.2, 0.5)]
    }

    // MARK: - 30-FPS budget tests
    // Each test calls analyze() 30 times (one second of video at 30 FPS).
    // The assertion verifies the total wall-clock time is under 1 second.

    func test_squatAnalysis_meets30FPSBudget() {
        let points = squatPoints
        let start = Date()
        for _ in 0..<30 {
            _ = FormAnalyzer.analyze(exercise: .squat, points: points)
        }
        XCTAssertLessThan(-start.timeIntervalSinceNow, 1.0,
                          "30 squat frames exceeded 1-second 30-FPS budget")
    }

    func test_pushUpAnalysis_meets30FPSBudget() {
        let points = pushUpPoints
        let start = Date()
        for _ in 0..<30 {
            _ = FormAnalyzer.analyze(exercise: .pushUp, points: points)
        }
        XCTAssertLessThan(-start.timeIntervalSinceNow, 1.0,
                          "30 push-up frames exceeded 1-second 30-FPS budget")
    }

    func test_lungeAnalysis_meets30FPSBudget() {
        let points = lungePoints
        let start = Date()
        for _ in 0..<30 {
            _ = FormAnalyzer.analyze(exercise: .lunge, points: points)
        }
        XCTAssertLessThan(-start.timeIntervalSinceNow, 1.0,
                          "30 lunge frames exceeded 1-second 30-FPS budget")
    }

    func test_plankAnalysis_meets30FPSBudget() {
        let points = plankPoints
        let start = Date()
        for _ in 0..<30 {
            _ = FormAnalyzer.analyze(exercise: .plank, points: points)
        }
        XCTAssertLessThan(-start.timeIntervalSinceNow, 1.0,
                          "30 plank frames exceeded 1-second 30-FPS budget")
    }

    // MARK: - XCTest measure baselines (establishes regression baselines)

    func test_squatAnalysis_measurePerformance() {
        let points = squatPoints
        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<30 {
                _ = FormAnalyzer.analyze(exercise: .squat, points: points)
            }
        }
    }

    func test_allExercises_measurePerformance() {
        let exercisePoints: [(TrackedExercise, [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint])] = [
            (.squat,  squatPoints),
            (.pushUp, pushUpPoints),
            (.lunge,  lungePoints),
            (.plank,  plankPoints),
        ]
        measure(metrics: [XCTClockMetric()]) {
            for (exercise, points) in exercisePoints {
                for _ in 0..<30 {
                    _ = FormAnalyzer.analyze(exercise: exercise, points: points)
                }
            }
        }
    }
}
