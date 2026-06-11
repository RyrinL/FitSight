import Vision
import CoreVideo

// MARK: - PoseDetector
//
// Thin, stateless wrapper around VNDetectHumanBodyPoseRequest.
// All work happens synchronously on the calling queue (videoQueue), so Vision
// inference never blocks the main thread or the Swift cooperative pool.
//
// Vision API reference
// ─────────────────────
//   VNDetectHumanBodyPoseRequest   — detects one body per call
//   VNHumanBodyPoseObservation     — contains all recognised joints
//   VNRecognizedPoint.confidence   — [0,1]; filter below 0.25 in the mapper
//   VNImageRequestHandler          — performs the request on a single frame
//
// Orientation note
//   Front-camera pixel buffers arrive in .right orientation (landscape-right
//   from the sensor's perspective). We pass .leftMirrored to account for the
//   horizontal flip that AVFoundation applies to the preview but NOT to the
//   raw pixel data. This keeps Vision's coordinate system consistent with
//   the mirrored preview the user sees on screen.

enum PoseDetector {

    /// Detects a single human body pose in `pixelBuffer`.
    ///
    /// - Parameters:
    ///   - pixelBuffer: Raw BGRA frame from AVCaptureVideoDataOutput.
    ///                  Must remain valid for the full duration of the call.
    ///   - orientation: Use `.leftMirrored` for the front camera.
    /// - Returns: The best (first) body-pose observation, or nil if none found
    ///            or if the Vision request itself fails.
    static func detect(in pixelBuffer: CVPixelBuffer,
                       orientation: CGImagePropertyOrientation) -> VNHumanBodyPoseObservation? {

        // VNDetectHumanBodyPoseRequest is single-person.
        // For group workouts, use VNDetectHumanBodyPosesRequest (plural).
        let request = VNDetectHumanBodyPoseRequest()

        // VNImageRequestHandler wraps one frame and executes all requests against it.
        // options: [:] — no extra metadata (e.g. camera intrinsics) needed here.
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: orientation,
                                            options: [:])
        do {
            try handler.perform([request])
        } catch {
            // Silently drop frames where Vision fails (device overload, bad buffer, etc.)
            return nil
        }

        // `results` is an array of observations sorted by confidence descending.
        // The first entry is the most-confidently detected person in the frame.
        return request.results?.first
    }
}
