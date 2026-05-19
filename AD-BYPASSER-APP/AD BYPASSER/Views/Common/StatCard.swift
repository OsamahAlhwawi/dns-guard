import SwiftUI

struct StatCard: View {
    let title: LocalizedStringKey
    let value: String
    var systemImage: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}
