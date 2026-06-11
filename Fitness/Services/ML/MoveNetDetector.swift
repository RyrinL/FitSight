import Vision
import CoreGraphics
import CoreVideo
import Accelerate
import Foundation

// MARK: - MoveNetPose
//
// Sendable snapshot produced by MoveNet — same coordinate space as Vision:
//   x: 0 = left,   1 = right
//   y: 0 = bottom, 1 = top   (Vision convention — MoveNet y is flipped on output)

struct MoveNetPose: Sendable {
    /// Keypoints above the confidence threshold, keyed by Vision joint name.
    let points:      [VNHumanBodyPoseObservation.JointName: CGPoint]
    /// 0–100 average confidence across visible joints.
    let confPercent: Int
}

// MARK: - MoveNetDetector
//
// Runs MoveNet Lightning (192×192 int8) on a CVPixelBuffer.
// Loaded once and reused across frames — do NOT create per-frame.
//
// Pipeline (all on videoQueue):
//   1. Crop to square (centre crop)
//   2. Scale to 192×192 with vImage
//   3. Convert BGRA → RGB int8
//   4. Copy into TFLite input tensor
//   5. Invoke interpreter
//   6. Parse output [1,1,17,3] → [JointName: CGPoint]
//
// TFLite dependency:
//   Add via SPM: https://github.com/google-ai-edge/LiteRT-swift  product: LiteRT
//   Then import LiteRT here instead of the placeholder below.

// ── Uncomment after adding the SPM package ──────────────────────────────────
// import LiteRT
// typealias Interpreter = LiteRT.Interpreter
// ────────────────────────────────────────────────────────────────────────────

final class MoveNetDetector {

    // MARK: - Constants

    static let inputSize   = 192              // Lightning variant
    static let keypointCount = 17
    static let confidenceThreshold: Float = 0.20

    // MoveNet keypoint index → VNHumanBodyPoseObservation.JointName
    static let jointMap: [VNHumanBodyPoseObservation.JointName] = [
        .nose,
        .leftEye,   .rightEye,
        .leftEar,   .rightEar,
        .leftShoulder, .rightShoulder,
        .leftElbow,    .rightElbow,
        .leftWrist,    .rightWrist,
        .leftHip,      .rightHip,
        .leftKnee,     .rightKnee,
        .leftAnkle,    .rightAnkle,
    ]

    // MARK: - Shared instance

    /// Returns nil when the model file is not bundled in the app.
    static let shared: MoveNetDetector? = {
        guard let path = Bundle.main.path(forResource: "movenet_lightning", ofType: "tflite") else {
            print("MoveNetDetector: movenet_lightning.tflite not found in bundle.")
            return nil
        }
        return try? MoveNetDetector(modelPath: path)
    }()

    // MARK: - Private state

    // Replace `Any` with `Interpreter` once the SPM package is added.
    private let interpreter: Any   // LiteRT.Interpreter
    private let side = MoveNetDetector.inputSize

    // MARK: - Init

    private init(modelPath: String) throws {
        // ── With LiteRT package ─────────────────────────────────────────────
        // var options = Interpreter.Options()
        // options.threadCount = 2
        // self.interpreter = try Interpreter(modelPath: modelPath, options: options)
        // try (self.interpreter as! Interpreter).allocateTensors()
        // ────────────────────────────────────────────────────────────────────
        self.interpreter = NSNull()   // placeholder until package is added
        print("MoveNetDetector: initialised (placeholder — add LiteRT package to activate).")
    }

    // MARK: - Detect

    /// Runs MoveNet on `pixelBuffer`. Returns nil if the model is not loaded
    /// or inference fails. Called synchronously on videoQueue.
    func detect(in pixelBuffer: CVPixelBuffer) -> MoveNetPose? {
        guard let rgbData = preprocess(pixelBuffer) else { return nil }

        // ── With LiteRT package ─────────────────────────────────────────────
        // guard let interp = interpreter as? Interpreter else { return nil }
        // do {
        //     try interp.copy(rgbData, toInputAt: 0)
        //     try interp.invoke()
        //     let output = try interp.output(at: 0)
        //     return parseOutput(output.data)
        // } catch {
        //     return nil
        // }
        // ────────────────────────────────────────────────────────────────────

        // Placeholder: return mock output so the pipeline can be tested visually
        // before TFLite is linked. Remove once LiteRT package is added.
        return nil
    }

    // MARK: - Preprocessing (no extra dependencies — Accelerate + CoreVideo)

    private func preprocess(_ pixelBuffer: CVPixelBuffer) -> Data? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let srcWidth  = CVPixelBufferGetWidth(pixelBuffer)
        let srcHeight = CVPixelBufferGetHeight(pixelBuffer)
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        // 1. Centre-crop to square
        let cropSize = min(srcWidth, srcHeight)
        let cropX    = (srcWidth  - cropSize) / 2
        let cropY    = (srcHeight - cropSize) / 2
        let rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let cropBase = base.advanced(by: cropY * rowBytes + cropX * 4)

        var srcBuffer = vImage_Buffer(
            data: cropBase,
            height: vImagePixelCount(cropSize),
            width:  vImagePixelCount(cropSize),
            rowBytes: rowBytes
        )

        // 2. Scale to 192×192
        let dstRowBytes = side * 4
        var dstStorage  = [UInt8](repeating: 0, count: side * dstRowBytes)
        var dstBuffer   = vImage_Buffer(
            data: &dstStorage,
            height: vImagePixelCount(side),
            width:  vImagePixelCount(side),
            rowBytes: dstRowBytes
        )
        let scaleErr = vImageScale_ARGB8888(&srcBuffer, &dstBuffer, nil, vImage_Flags(0))
        guard scaleErr == kvImageNoError else { return nil }

        // 3. Convert BGRA → RGB int8 and pack into Data
        //    MoveNet expects uint8 [0,255]; most TFLite models accept uint8 directly.
        var rgbBytes = [Int8](repeating: 0, count: side * side * 3)
        var rgbIdx   = 0
        for i in 0 ..< side * side {
            let base4 = i * 4
            rgbBytes[rgbIdx]     = Int8(bitPattern: dstStorage[base4 + 2]) // R
            rgbBytes[rgbIdx + 1] = Int8(bitPattern: dstStorage[base4 + 1]) // G
            rgbBytes[rgbIdx + 2] = Int8(bitPattern: dstStorage[base4 + 0]) // B
            rgbIdx += 3
        }
        return Data(bytes: rgbBytes, count: rgbBytes.count)
    }

    // MARK: - Output parsing

    /// Parses the flat [1,1,17,3] float32 output tensor into a MoveNetPose.
    /// Each keypoint is [y_norm, x_norm, confidence], all in [0,1].
    /// y is flipped to match Vision's convention (0 = bottom).
    func parseOutput(_ rawData: Data) -> MoveNetPose {
        let floats = rawData.withUnsafeBytes {
            Array($0.bindMemory(to: Float32.self))
        }

        var points      = [VNHumanBodyPoseObservation.JointName: CGPoint]()
        var totalConf   = Float(0)
        var visibleCount = 0

        for idx in 0 ..< Self.keypointCount {
            let base       = idx * 3
            let yNorm      = floats[base]       // MoveNet: 0=top
            let xNorm      = floats[base + 1]
            let confidence = floats[base + 2]

            guard confidence >= Self.confidenceThreshold else { continue }

            let jointName = Self.jointMap[idx]
            // Flip Y to match Vision coordinate space (0 = bottom)
            points[jointName] = CGPoint(x: Double(xNorm), y: Double(1 - yNorm))

            totalConf += confidence
            visibleCount += 1
        }

        let confPercent = visibleCount > 0
            ? Int((totalConf / Float(visibleCount)) * 100)
            : 0

        return MoveNetPose(points: points, confPercent: confPercent)
    }
}

// MARK: - MoveNetPose → SquatJoints

extension MoveNetPose {

    private func point(_ name: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
        points[name]
    }

    /// Extracts SquatJoints from MoveNet output. Returns nil if any mandatory
    /// leg joint is missing.
    func squatJoints() -> SquatJoints? {
        guard
            let lHip   = point(.leftHip),
            let lKnee  = point(.leftKnee),
            let lAnkle = point(.leftAnkle),
            let rHip   = point(.rightHip),
            let rKnee  = point(.rightKnee),
            let rAnkle = point(.rightAnkle)
        else { return nil }

        return SquatJoints(
            leftHip:       lHip,   leftKnee:  lKnee,  leftAnkle:  lAnkle,
            rightHip:      rHip,   rightKnee: rKnee,  rightAnkle: rAnkle,
            leftShoulder:  point(.leftShoulder),
            rightShoulder: point(.rightShoulder)
        )
    }
}
