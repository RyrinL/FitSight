import SwiftUI
import Vision

// MARK: - SquatSkeletonOverlayView
//
// Canvas-based skeleton overlay for the squat form coach.
// Draws bones (lines) and joints (circles) on top of the camera preview.
//
// Coordinate mapping
// ───────────────────
//   Vision uses (0,0) = bottom-left, (1,1) = top-right.
//   SwiftUI Canvas uses (0,0) = top-left (Y inverted).
//   The `display(_:in:)` helper flips Y: screen.y = (1 – vision.y) × height.
//
//   With .resizeAspectFill the camera frame is cropped to fill the view.
//   Vision landmarks are computed on the uncropped frame, so joints near the
//   extreme edges of the frame may appear slightly offset — acceptable for MVP.
//
// Rendering layers (back to front)
//   1. Bones  — semi-transparent lines connecting adjacent joints
//   2. Joints — filled circles; issue joints drawn larger and in red

struct SquatSkeletonOverlayView: View {

    /// Smoothed Vision-space joint positions (y=0 at bottom), keyed by joint name.
    let points: [VNHumanBodyPoseObservation.JointName: CGPoint]

    /// Joints flagged by the form analyzer — rendered red for visual cueing.
    let issueJoints: Set<VNHumanBodyPoseObservation.JointName>

    var body: some View {
        Canvas { ctx, size in
            drawBones(in: ctx, size: size)
            drawJoints(in: ctx, size: size)
            if let annotation = depthAnnotation(size: size) {
                drawDepthAnnotation(annotation, in: ctx)
            }
        }
        .allowsHitTesting(false)   // transparent to touch events
    }

    // MARK: - Bones

    private func drawBones(in ctx: GraphicsContext, size: CGSize) {
        for (nameA, nameB) in Self.boneConnections {
            guard let pa = points[nameA], let pb = points[nameB] else { continue }

            var path = Path()
            path.move(to: display(pa, in: size))
            path.addLine(to: display(pb, in: size))

            let hasIssue = issueJoints.contains(nameA) || issueJoints.contains(nameB)
            let color: Color = hasIssue ? .red : .white
            ctx.stroke(path, with: .color(color.opacity(0.70)), lineWidth: 2.5)
        }
    }

    // MARK: - Joints

    private func drawJoints(in ctx: GraphicsContext, size: CGSize) {
        for (joint, pt) in points {
            let isIssue  = issueJoints.contains(joint)
            let radius: CGFloat = isIssue ? 8 : 5
            let color: Color    = isIssue ? .red : .mint

            let center = display(pt, in: size)
            let rect   = CGRect(x: center.x - radius / 2,
                                y: center.y - radius / 2,
                                width: radius, height: radius)

            ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.9)))

            // Outer ring on issue joints for extra visual emphasis.
            if isIssue {
                let ring = Path(ellipseIn: rect.insetBy(dx: -4, dy: -4))
                ctx.stroke(ring, with: .color(Color.red.opacity(0.40)), lineWidth: 1.5)
            }
        }
    }

    // MARK: - Depth annotation
    //
    // Draws a faint horizontal guideline at the knee level to help the user
    // gauge when they've reached parallel depth.

    private struct DepthAnnotation {
        let kneeY: CGFloat   // screen Y coordinate
        let label: String
        let color: Color
    }

    private func depthAnnotation(size: CGSize) -> DepthAnnotation? {
        let kneeJoints: [VNHumanBodyPoseObservation.JointName] = [.leftKnee, .rightKnee]
        let ys = kneeJoints.compactMap { points[$0].map { display($0, in: size).y } }
        guard !ys.isEmpty else { return nil }
        let avgKneeY = ys.reduce(0, +) / CGFloat(ys.count)
        return DepthAnnotation(kneeY: avgKneeY, label: "─── parallel", color: .white.opacity(0.3))
    }

    private func drawDepthAnnotation(_ ann: DepthAnnotation, in ctx: GraphicsContext) {
        var line = Path()
        // Draw a dashed horizontal guideline across the full width at knee height.
        line.move(to: CGPoint(x: 0, y: ann.kneeY))
        line.addLine(to: CGPoint(x: 10_000, y: ann.kneeY))
        ctx.stroke(line,
                   with: .color(ann.color),
                   style: StrokeStyle(lineWidth: 1, dash: [6, 8]))
    }

    // MARK: - Coordinate transform

    /// Converts Vision-space (y=0 at bottom) to SwiftUI Canvas-space (y=0 at top).
    private func display(_ pt: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: pt.x * size.width, y: (1 - pt.y) * size.height)
    }

    // MARK: - Skeleton topology
    //
    // Defines which joints to connect with bones. The list covers the full body
    // so the overlay works even when the exercise picker shows non-squat exercises.

    static let boneConnections: [(VNHumanBodyPoseObservation.JointName,
                                   VNHumanBodyPoseObservation.JointName)] = [
        // Shoulder girdle
        (.leftShoulder,  .rightShoulder),
        // Left arm
        (.leftShoulder,  .leftElbow),
        (.leftElbow,     .leftWrist),
        // Right arm
        (.rightShoulder, .rightElbow),
        (.rightElbow,    .rightWrist),
        // Torso
        (.leftShoulder,  .leftHip),
        (.rightShoulder, .rightHip),
        // Hip bar
        (.leftHip,       .rightHip),
        // Left leg
        (.leftHip,       .leftKnee),
        (.leftKnee,      .leftAnkle),
        // Right leg
        (.rightHip,      .rightKnee),
        (.rightKnee,     .rightAnkle),
    ]
}
