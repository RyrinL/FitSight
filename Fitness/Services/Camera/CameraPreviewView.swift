import SwiftUI
import AVFoundation

// MARK: - CameraPreviewView
//
// SwiftUI wrapper around AVCaptureVideoPreviewLayer.
//
// Why UIViewRepresentable instead of a UIKit-in-SwiftUI wrapper?
//   AVCaptureVideoPreviewLayer must be the backing layer of a UIView
//   (set via layerClass) for the system to size it correctly during
//   device rotations and split-screen transitions. Adding it as a sublayer
//   causes layout bugs in those edge cases.
//
// Gravity: .resizeAspectFill matches the skeleton overlay's coordinate
//   calculation — both fill the view bounds, so Vision-normalised points
//   map cleanly to screen pixels.

struct CameraPreviewView: UIViewRepresentable {

    /// The running capture session to display.
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraLiveView {
        let view = CameraLiveView()
        view.previewLayer.session      = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraLiveView, context: Context) {
        // Session changes (e.g. reconfiguration) are reflected automatically
        // by AVCaptureVideoPreviewLayer; no manual update needed here.
        uiView.previewLayer.session = session
    }
}

// MARK: - Backing UIView

/// UIView whose CALayer is promoted to AVCaptureVideoPreviewLayer by overriding
/// `layerClass`. This is Apple's recommended pattern for embedding camera previews.
final class CameraLiveView: UIView {

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // Force-cast is safe: layerClass guarantees this type.
        layer as! AVCaptureVideoPreviewLayer
    }
}
