import AVFoundation
import Vision
import CoreMedia

// MARK: - PoseBackend
//
// Selects which pose-detection model the frame processor uses.
//   .vision   — Apple Vision (VNDetectHumanBodyPoseRequest, no extra dependency)
//   .moveNet  — TF MoveNet Lightning (requires LiteRT SPM package + bundled .tflite)

enum PoseBackend {
    case vision
    case moveNet
}

// MARK: - UnifiedPoseResult
//
// Sendable snapshot produced by either backend, in Vision coordinate space:
//   x: 0=left, 1=right
//   y: 0=bottom, 1=top

struct UnifiedPoseResult: Sendable {
    let displayPoints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    let squatJoints:   SquatJoints?
    let confPercent:   Int
    let backend:       PoseBackend
}

// MARK: - FrameProcessor
//
// AVCaptureVideoDataOutputSampleBufferDelegate that throttles frames and runs
// pose detection on every Nth frame. Supports Vision (default) and MoveNet
// via the `backend` property — switch at any time before frames arrive.
//
// Thread safety of callbacks:
//   Set exactly ONCE from ViewModel.init() before the session starts.

final class FrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: - Callbacks (set before session starts)

    var onPoseResult: ((UnifiedPoseResult) -> Void)?
    var onPoseLost:   (() -> Void)?

    // MARK: - Backend selection

    /// Defaults to Vision. Switch to .moveNet after bundling movenet_lightning.tflite.
    var backend: PoseBackend = MoveNetDetector.shared != nil ? .moveNet : .vision

    /// Minimum average joint confidence (0–100) to render the skeleton.
    /// Below this threshold the person is too far away or partially occluded.
    private static let minimumConfidence = 25

    // MARK: - Internal

    let videoQueue = DispatchQueue(label: "fitsight.squat.video", qos: .userInitiated)

    private var frameCounter = 0
    // Process every frame. The camera runs at 30 FPS, so the skeleton tracks at
    // the full rate (no perceived lag) and a 60-frame action window spans exactly
    // 2 seconds — the cadence the action classifier expects.
    private static let frameInterval = 1

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        frameCounter &+= 1
        guard
            frameCounter % Self.frameInterval == 0,
            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }

        switch backend {
        case .moveNet: runMoveNet(pixelBuffer)
        case .vision:  runVision(pixelBuffer)
        }
    }

    // MARK: - MoveNet path

    private func runMoveNet(_ pixelBuffer: CVPixelBuffer) {
        guard let detector = MoveNetDetector.shared,
              let pose     = detector.detect(in: pixelBuffer)
        else {
            // MoveNet unavailable or no detection — fall back to Vision
            runVision(pixelBuffer)
            return
        }

        if pose.points.isEmpty || pose.confPercent < Self.minimumConfidence {
            onPoseLost?()
            return
        }

        onPoseResult?(UnifiedPoseResult(
            displayPoints: pose.points,
            squatJoints:   pose.squatJoints(),
            confPercent:   pose.confPercent,
            backend:       .moveNet
        ))
    }

    // MARK: - Vision path

    private func runVision(_ pixelBuffer: CVPixelBuffer) {
        guard let obs = PoseDetector.detect(in: pixelBuffer, orientation: .leftMirrored) else {
            onPoseLost?()
            return
        }

        let displayPoints = PoseObservationMapper.displayPoints(from: obs)
        let conf = PoseObservationMapper.averageConfidencePercent(from: obs)
        guard !displayPoints.isEmpty, conf >= Self.minimumConfidence else {
            onPoseLost?()
            return
        }

        onPoseResult?(UnifiedPoseResult(
            displayPoints: displayPoints,
            squatJoints:   PoseObservationMapper.squatJoints(from: obs),
            confPercent:   conf,
            backend:       .vision
        ))
    }
}
