import SwiftUI

struct PrimaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var isWorking: Bool = false
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isWorking {
                    ProgressView().tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.borderedProminent)
        .tint(isDestructive ? .red : .accentColor)
        .controlSize(.large)
        .disabled(isWorking)
    }
}
