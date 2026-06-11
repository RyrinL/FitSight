import SwiftUI

struct CircularProgress: View {
    let progress: Double   // 0…1
    let label: String
    var size: CGFloat = 96
    var lineWidth: CGFloat = 12
    var tint: Color = .mint

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: progress)
            Text(label)
                .font(.headline)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue(label)
    }
}
