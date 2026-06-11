import SwiftUI

struct FeatureRow: View {
    let title: String
    let subtitle: String
    let symbolName: String
    var tint: Color = .mint

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbolName)
                .font(.title3)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
