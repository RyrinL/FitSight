import AVFoundation
import Combine
import Foundation

// MARK: - CameraManager
//
// Owns the AVCaptureSession lifecycle: permission checks, device configuration,
// start/stop control. Deliberately decoupled from pose detection so that the
// camera pipeline can be unit-tested or swapped (e.g. for a simulator stub)
// without touching any Vision code.
//
// Thread model
// ─────────────
//   Main thread   — @Published state, public API (called from SwiftUI)
//   sessionQueue (serial GCD) — all AVCaptureSession mutations

final class CameraManager: ObservableObject {

    // MARK: - Published state

    @Published private(set) var permission: CameraPermission = .unknown
    @Published private(set) var isRunning  = false

    // MARK: - Session (let constant — safe to read from any thread once set in init)

    /// The live capture session. Bind `CameraPreviewView` to this object.
    let session = AVCaptureSession()

    // MARK: - Private

    /// Serialises all AVCaptureSession mutations to avoid concurrent-access crashes.
    private let sessionQueue = DispatchQueue(
        label: "fitsight.squat.camera.session", qos: .userInitiated)

    /// Prevents double-configuration across start() calls.
    private var isConfigured = false

    // MARK: - Init

    init() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:            permission = .authorized
        case .denied, .restricted:   permission = .denied
        default:                     permission = .unknown
        }
    }

    // MARK: - Permission

    var permissionMessage: String {
        switch permission {
        case .unknown:     return "Enable camera access to coach your squat form."
        case .authorized:  return "Camera ready."
        case .denied:      return "Camera is blocked. Enable it in Settings → Privacy → Camera → FitSight."
        case .unavailable: return "No camera found on this device."
        }
    }

    func requestAccess(onGranted: @escaping () -> Void = {}) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { [weak self] in
                self?.permission = .authorized
                onGranted()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async { [weak self] in
                    self?.permission = granted ? .authorized : .denied
                    if granted { onGranted() }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async { [weak self] in self?.permission = .denied }
        @unknown default:
            DispatchQueue.main.async { [weak self] in self?.permission = .unavailable }
        }
    }

    // MARK: - Session control

    func start(frameProcessor: FrameProcessor) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureIfNeeded(frameProcessor: frameProcessor)
            guard self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async { [weak self] in self?.isRunning = true }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async { [weak self] in self?.isRunning = false }
        }
    }

    // MARK: - Private configuration (runs on sessionQueue)

    private func configureIfNeeded(frameProcessor: FrameProcessor) {
        guard !isConfigured else { return }

        session.beginConfiguration()
        session.sessionPreset = .medium

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                  for: .video, position: .front),
            let input  = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            DispatchQueue.main.async { [weak self] in self?.permission = .unavailable }
            return
        }
        session.addInput(input)

        // Pin the capture rate to a constant 30 FPS. Without this, iOS lowers the
        // front-camera frame rate in dim lighting, which would stretch the
        // 60-frame action window past its intended 2-second duration and make the
        // skeleton update unevenly. 1/30 s min == max frame duration locks it.
        if let range = device.activeFormat.videoSupportedFrameRateRanges.first,
           range.minFrameRate <= 30, range.maxFrameRate >= 30,
           (try? device.lockForConfiguration()) != nil {
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
            device.unlockForConfiguration()
        }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(frameProcessor, queue: frameProcessor.videoQueue)

        if session.canAddOutput(output) { session.addOutput(output) }

        if let conn = output.connection(with: .video),
           conn.isVideoMirroringSupported {
            conn.isVideoMirrored = true
        }

        session.commitConfiguration()
        isConfigured = true
    }
}
