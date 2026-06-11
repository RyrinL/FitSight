import AVFoundation
import Vision
import Foundation

// MARK: - Sendable value crossing PoseProcessor actor → main thread

private struct PoseResult: Sendable {
    let displayPoints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    let issueJoints: Set<VNHumanBodyPoseObservation.JointName>
    let confPercent: Int
    let formScore: Int
    let feedbackText: String
    let feedbackSeverity: FormSeverity
    let shouldUpdateFeedback: Bool
    let didCompleteRep: Bool
}

// MARK: - Actor: serializes all mutable per-frame state

private actor PoseProcessor {

    private var smoothed: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    private var scoreBuffer: [Int] = []
    private var lastFeedbackText = ""
    private var lastFeedbackTime = Date.distantPast
    private var wasInRepBottom = false

    private static let smoothAlpha: Double = 0.5
    private static let scoreBufferSize = 8
    private static let debounceInterval: TimeInterval = 0.45

    func process(
        cueText: String,
        cueSeverity: FormSeverity,
        cueScore: Int,
        cueIsBottom: Bool,
        issueJoints: Set<VNHumanBodyPoseObservation.JointName>,
        filteredPoints: [VNHumanBodyPoseObservation.JointName: CGPoint],
        confPercent: Int
    ) -> PoseResult {

        for (name, raw) in filteredPoints {
            if let prev = smoothed[name] {
                smoothed[name] = CGPoint(
                    x: Self.smoothAlpha * raw.x + (1 - Self.smoothAlpha) * prev.x,
                    y: Self.smoothAlpha * raw.y + (1 - Self.smoothAlpha) * prev.y
                )
            } else {
                smoothed[name] = raw
            }
        }

        scoreBuffer.append(cueScore)
        if scoreBuffer.count > Self.scoreBufferSize { scoreBuffer.removeFirst() }
        let avgScore = scoreBuffer.reduce(0, +) / max(scoreBuffer.count, 1)

        let isError = cueSeverity == .error
        let changed = cueText != lastFeedbackText
        let cooldown = Date().timeIntervalSince(lastFeedbackTime) >= Self.debounceInterval
        let shouldUpdate = changed && (isError || cooldown)
        if shouldUpdate {
            lastFeedbackText = cueText
            lastFeedbackTime = Date()
        }

        var didCompleteRep = false
        if cueIsBottom, !wasInRepBottom {
            wasInRepBottom = true
        } else if !cueIsBottom, wasInRepBottom {
            wasInRepBottom = false
            didCompleteRep = true
        }

        return PoseResult(
            displayPoints: smoothed,
            issueJoints: issueJoints,
            confPercent: confPercent,
            formScore: avgScore,
            feedbackText: cueText,
            feedbackSeverity: cueSeverity,
            shouldUpdateFeedback: shouldUpdate,
            didCompleteRep: didCompleteRep
        )
    }

    func reset() {
        smoothed = [:]
        scoreBuffer = []
        lastFeedbackText = ""
        lastFeedbackTime = .distantPast
        wasInRepBottom = false
    }

    func clearSmoothed() {
        smoothed = [:]
    }
}

// MARK: - CameraFormCoach

final class CameraFormCoach: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: - Published state

    @Published var permission: CameraPermission = .unknown
    @Published var feedback = "Position your full body in frame."
    @Published var feedbackSeverity: FormSeverity = .caution
    @Published var formScore: Int = 0
    @Published var poseConfidencePercent = 0
    @Published var repCount = 0
    @Published var isRunning = false
    @Published var currentExercise: TrackedExercise = .squat {
        didSet { lastKnownExercise = currentExercise }
    }

    /// Whether spoken form feedback is on. Persisted across launches.
    @Published var voiceEnabled: Bool = UserDefaults.standard.object(forKey: "fitsight.voiceCoachEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(voiceEnabled, forKey: Self.voiceDefaultsKey)
            if !voiceEnabled { voice.stop() }
        }
    }
    private static let voiceDefaultsKey = "fitsight.voiceCoachEnabled"
    private let voice = VoiceCoach()

    @Published var poseDisplayPoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    @Published var issueJoints: Set<VNHumanBodyPoseObservation.JointName> = []

    /// Aspect ratio (width / height) of the camera image in Vision's oriented
    /// space. Lets the skeleton overlay match the preview's .resizeAspectFill crop.
    @Published var sourceAspect: CGFloat = 0

    // MARK: - Session

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "fitsight.camera.session")
    private let videoQueue   = DispatchQueue(label: "fitsight.camera.video")

    // MARK: - Hot-path state
    // Accessed only from their respective queues (sessionQueue / videoQueue).

    private var isConfigured = false
    private var frameCounter = 0
    private var missedFrameCount = 0
    // Written from main thread (currentExercise.didSet), read from videoQueue.
    // One-directional write; worst case: stale exercise for one frame.
    private var lastKnownExercise: TrackedExercise = .squat
    private let poseProcessor = PoseProcessor()

    // Process every frame so the skeleton tracks smoothly at the full 30 fps
    // instead of the choppy 10 fps that frame-skipping produced.
    private static let frameInterval = 1
    // Clear skeleton only after this many consecutive missed detections (~0.5 s at 30 fps).
    private static let missedFrameThreshold = 15
    // Minimum joint confidence to draw. Kept low so the skeleton still appears
    // when the user is close or partially framed (was dropping out entirely).
    private static let minJointConfidence: Float = 0.10

    // MARK: - Computed

    var permissionMessage: String {
        switch permission {
        case .unknown:     return "Camera access lets FitSight coach exercise form."
        case .authorized:  return "Camera ready."
        case .denied:      return "Camera permission is off. Enable it in Settings."
        case .unavailable: return "No camera is available on this device."
        }
    }

    // MARK: - Permission & session control

    func requestAccessIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { [weak self] in
                self?.permission = .authorized
                self?.startSession()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.permission = granted ? .authorized : .denied
                    if granted { self.startSession() }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async { [weak self] in self?.permission = .denied }
        @unknown default:
            DispatchQueue.main.async { [weak self] in self?.permission = .unavailable }
        }
    }

    func toggleSession() { isRunning ? stopSession() : requestAccessIfNeeded() }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureIfNeeded()
            guard self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async { [weak self] in self?.isRunning = true }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
                self?.voice.stop()
            }
        }
    }

    func resetReps() {
        repCount = 0
        let processor = poseProcessor
        Task { await processor.reset() }
    }

    // MARK: - Session configuration (called from sessionQueue)

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        session.beginConfiguration()
        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input  = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            DispatchQueue.main.async { [weak self] in
                self?.permission = .unavailable
                self?.feedback   = "No usable camera found."
            }
            return
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(output) { session.addOutput(output) }

        if let conn = output.connection(with: .video) {
            // Rotate frames to upright portrait at capture time so Vision receives an
            // upright person (high confidence, stable tracking) and we can feed it `.up`.
            if conn.isVideoOrientationSupported { conn.videoOrientation = .portrait }
            // Mirror to match the selfie preview. Must disable auto-adjust first;
            // setting isVideoMirrored while it's on raises an exception that aborts config.
            if conn.isVideoMirroringSupported {
                conn.automaticallyAdjustsVideoMirroring = false
                conn.isVideoMirrored = true
            }
        }

        session.commitConfiguration()
        isConfigured = true
    }

    // MARK: - Frame capture (called by AVFoundation on videoQueue)

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        frameCounter &+= 1
        guard frameCounter % CameraFormCoach.frameInterval == 0,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // The connection already rotates frames to upright portrait, so the buffer
        // dimensions are the displayed dimensions — aspect is width / height directly.
        if sourceAspect == 0 {
            let bufW = CVPixelBufferGetWidth(pixelBuffer)
            let bufH = CVPixelBufferGetHeight(pixelBuffer)
            if bufW > 0, bufH > 0 {
                let aspect = CGFloat(bufW) / CGFloat(bufH)
                DispatchQueue.main.async { [weak self] in self?.sourceAspect = aspect }
            }
        }

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .up,
                                            options: [:])
        try? handler.perform([request])

        guard let obs = request.results?.first,
              let points = try? obs.recognizedPoints(.all),
              !points.isEmpty else {
            missedFrameCount += 1
            if missedFrameCount >= Self.missedFrameThreshold {
                DispatchQueue.main.async { [weak self] in self?.clearPose() }
            }
            return
        }
        missedFrameCount = 0

        let exercise    = lastKnownExercise
        let confident   = points.values.filter { $0.confidence > 0.35 }
        let avgConf     = confident.isEmpty ? 0.0
            : confident.map { Double($0.confidence) }.reduce(0, +) / Double(confident.count)
        let confPercent = Int(avgConf * 100)

        let analysis = FormAnalyzer.analyze(exercise: exercise, points: points)

        let filteredPoints = points.reduce(into: [VNHumanBodyPoseObservation.JointName: CGPoint]()) { dict, pair in
            guard pair.value.confidence > Self.minJointConfidence else { return }
            dict[pair.key] = CGPoint(x: Double(pair.value.location.x), y: Double(pair.value.location.y))
        }

        let processor = poseProcessor
        Task { [weak self, processor] in
            let result = await processor.process(
                cueText:        analysis.cue.text,
                cueSeverity:    analysis.cue.severity,
                cueScore:       analysis.cue.formScore,
                cueIsBottom:    analysis.cue.isRepBottom,
                issueJoints:    analysis.issueJoints,
                filteredPoints: filteredPoints,
                confPercent:    confPercent
            )
            DispatchQueue.main.async { [weak self] in self?.apply(result) }
        }
    }

    // MARK: - UI application (main thread)

    private func apply(_ result: PoseResult) {
        poseConfidencePercent = result.confPercent
        poseDisplayPoints     = result.displayPoints
        issueJoints           = result.issueJoints
        formScore             = result.formScore
        if result.shouldUpdateFeedback {
            feedback         = result.feedbackText
            feedbackSeverity = result.feedbackSeverity
            if voiceEnabled {
                voice.speak(result.feedbackText, severity: result.feedbackSeverity)
            }
        }
        if result.didCompleteRep {
            repCount += 1
            FitHaptic.impact(.medium)
            if voiceEnabled { voice.announceRep(repCount) }
        }
    }

    private func clearPose() {
        poseConfidencePercent = 0
        poseDisplayPoints     = [:]
        issueJoints           = []
        let processor = poseProcessor
        Task { await processor.clearSmoothed() }
        let message = "Move back until your full body is visible."
        guard feedback != message else { return }
        feedback         = message
        feedbackSeverity = .caution
    }
}
