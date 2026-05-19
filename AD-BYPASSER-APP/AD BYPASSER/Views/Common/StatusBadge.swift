import SwiftUI

struct StatusBadge: View {
    let status: DNSStatusResponse.Status

    var color: Color {
        switch status {
        case .active: return .green
        case .pending_activation: return .orange
        case .suspended: return .red
        case .expired: return .gray
        case .unknown: return .gray
        }
    }

    var titleKey: LocalizedStringKey {
        switch status {
        case .active: return "status.active"
        case .pending_activation: return "status.pending"
        case .suspended: return "status.suspended"
        case .expired: return "status.expired"
        case .unknown: return "status.unknown"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(titleKey)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
        .foregroundStyle(color)
    }
}
