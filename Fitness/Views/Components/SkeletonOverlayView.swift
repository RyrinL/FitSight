import SwiftUI
import Vision

/// Draws the detected body skeleton on top of the camera preview.
///
/// Coordinate mapping: Vision uses (0,0) = bottom-left, (1,1) = top-right.
/// SwiftUI Canvas uses (0,0) = top-left. We flip Y and scale to the canvas size.
/// With `.resizeAspectFill` the mapping is approximate — central joints are accurate;
/// extreme edges may appear slightly offset due to crop.
struct SkeletonOverlayView: View {

    /// Smoothed Vision-space points (y=0 at bottom), keyed by joint name.
    let points: [VNHumanBodyPoseObservation.JointName: CGPoint]
    /// Joints highlighted in red because the analyzer flagged a form error there.
    let issueJoints: Set<VNHumanBodyPoseObservation.JointName>
    /// Aspect ratio (width / height) of the camera image, so the overlay matches
    /// the preview's `.resizeAspectFill` crop. 0 = unknown → plain stretch fallback.
    var sourceAspect: CGFloat = 0

    var body: some View {
        Canvas { ctx, size in
            drawBones(ctx, size)
            drawJoints(ctx, size)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Drawing

    private func drawBones(_ ctx: GraphicsContext, _ size: CGSize) {
        for (a, b) in Self.bones {
            guard let pa = points[a], let pb = points[b] else { continue }
            var path = Path()
            path.move(to: display(pa, size))
            path.addLine(to: display(pb, size))

            let hasIssue = issueJoints.contains(a) || issueJoints.contains(b)
            let color: Color = hasIssue ? .red : .white
            ctx.stroke(path, with: .color(color.opacity(0.72)), lineWidth: 2.5)
        }
    }

    private func drawJoints(_ ctx: GraphicsContext, _ size: CGSize) {
        for (joint, pt) in points {
            let isIssue  = issueJoints.contains(joint)
            let r: CGFloat = isIssue ? 7 : 5
            let color: Color = isIssue ? Color(red: 1, green: 0.23, blue: 0.19) : .mint

            let center = display(pt, size)
            let rect   = CGRect(x: center.x - r / 2, y: center.y - r / 2, width: r, height: r)
            ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.9)))

            // Outer ring on issue joints for emphasis.
            if isIssue {
                let ring = Path(ellipseIn: rect.insetBy(dx: -3, dy: -3))
                ctx.stroke(ring, with: .color(Color.red.opacity(0.45)), lineWidth: 1.5)
            }
        }
    }

    // MARK: - Coordinate transform

    /// Flip Vision Y-axis and map to the canvas, replicating `.resizeAspectFill`:
    /// the image is scaled to *cover* the view and centered, so points stay on
    /// the body instead of being stretched across the whole screen.
    private func display(_ pt: CGPoint, _ size: CGSize) -> CGPoint {
        guard sourceAspect > 0 else {
            return CGPoint(x: pt.x * size.width, y: (1 - pt.y) * size.height)
        }
        // Image measured in units where height = 1, width = sourceAspect.
        let scale   = max(size.width / sourceAspect, size.height)
        let scaledW = sourceAspect * scale
        let scaledH = scale
        let offsetX = (size.width  - scaledW) / 2
        let offsetY = (size.height - scaledH) / 2
        return CGPoint(x: offsetX + pt.x * scaledW,
                       y: offsetY + (1 - pt.y) * scaledH)
    }

    // MARK: - Skeleton topology

    static let bones: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        // Shoulders
        (.leftShoulder,  .rightShoulder),
        // Left arm
        (.leftShoulder,  .leftElbow),
        (.leftElbow,     .leftWrist),
        // Right arm
        (.rightShoulder, .rightElbow),
        (.rightElbow,    .rightWrist),
        // Torso sides
        (.leftShoulder,  .leftHip),
        (.rightShoulder, .rightHip),
        // Hips
        (.leftHip,       .rightHip),
        // Left leg
        (.leftHip,       .leftKnee),
        (.leftKnee,      .leftAnkle),
        // Right leg
        (.rightHip,      .rightKnee),
        (.rightKnee,     .rightAnkle),
    ]
}
