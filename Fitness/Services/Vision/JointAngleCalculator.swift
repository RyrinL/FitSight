import CoreGraphics
import Foundation

// MARK: - JointAngleCalculator
//
// Pure, stateless math functions for biomechanical measurements.
// No Vision or AVFoundation imports — all inputs are plain CGPoint values
// in Vision's normalised space: (0,0) = bottom-left, (1,1) = top-right.
//
// All functions are thread-safe (value types only, no shared mutable state).

enum JointAngleCalculator {

    // MARK: - Core angle computation

    /// Angle at `vertex` formed by the rays vertex→`a` and vertex→`b`, in degrees.
    ///
    /// Uses the dot-product formula to avoid atan2 quadrant ambiguity:
    ///   cos θ = (v1 · v2) / (|v1| × |v2|)
    ///
    /// Returns 180° for degenerate (zero-length) vectors so callers can treat
    /// a missing joint as a straight (non-flagged) segment.
    static func angle(at vertex: CGPoint, from a: CGPoint, to b: CGPoint) -> Double {
        let v1 = CGVector(dx: a.x - vertex.x, dy: a.y - vertex.y)
        let v2 = CGVector(dx: b.x - vertex.x, dy: b.y - vertex.y)
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let mag = hypot(v1.dx, v1.dy) * hypot(v2.dx, v2.dy)
        guard mag > 1e-6 else { return 180.0 }
        // Clamp cos value to [-1, 1] to guard against floating-point rounding past ±1.
        return acos(max(-1.0, min(1.0, dot / mag))) * 180 / Double.pi
    }

    // MARK: - Squat-specific measurements

    /// Knee flexion angle (degrees).
    ///   180° = standing (straight leg)
    ///   ~90° = parallel squat depth
    ///   <90° = below parallel (deep squat)
    static func kneeAngle(hip: CGPoint, knee: CGPoint, ankle: CGPoint) -> Double {
        angle(at: knee, from: hip, to: ankle)
    }

    /// Forward lean of the torso, measured as the angle between the
    /// shoulder-to-hip vector and the vertical axis, in degrees.
    ///   0°  = perfectly upright
    ///   22° = threshold for "excessive lean" coaching cue
    ///   90° = horizontal (lying down)
    ///
    /// Vision's Y-axis (0 = bottom) means a higher Y value is physically higher
    /// on screen, which is already the correct convention for atan2 here.
    static func torsoLean(shoulderMid: CGPoint, hipMid: CGPoint) -> Double {
        let dx = abs(shoulderMid.x - hipMid.x)   // horizontal displacement
        let dy = abs(shoulderMid.y - hipMid.y)   // vertical displacement
        return atan2(dx, dy) * 180 / Double.pi
    }

    /// Absolute horizontal distance between two points in normalised [0,1] space.
    /// Used for knee-valgus (cave-in) detection.
    static func horizontalDistance(_ a: CGPoint, _ b: CGPoint) -> Double {
        abs(a.x - b.x)
    }

    // MARK: - Geometry utilities

    /// Returns the midpoint of two joints — used for hip-centre and shoulder-centre.
    static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    /// Projects point `p` onto the line defined by `lineStart`→`lineEnd`,
    /// and returns the signed perpendicular deviation (positive = above the line
    /// in Vision space, i.e. higher Y = higher on screen).
    ///
    /// Used for hip-deviation checks in push-up and plank analysis.
    static func perpendicularDeviation(of p: CGPoint,
                                       from lineStart: CGPoint,
                                       to lineEnd: CGPoint) -> Double {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lenSq = dx * dx + dy * dy
        guard lenSq > 1e-6 else { return 0 }
        let t = ((p.x - lineStart.x) * dx + (p.y - lineStart.y) * dy) / lenSq
        let projected = CGPoint(x: lineStart.x + t * dx, y: lineStart.y + t * dy)
        return Double(p.y - projected.y)
    }
}
