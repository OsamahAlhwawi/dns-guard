import SwiftUI

struct OnboardingView: View {
    let onFinished: () -> Void
    @State private var page: Int = 0

    private let slides: [Slide] = [
        Slide(systemImage: "shield.lefthalf.filled", titleKey: "onboarding.slide1.title", bodyKey: "onboarding.slide1.body"),
        Slide(systemImage: "lock.shield", titleKey: "onboarding.slide2.title", bodyKey: "onboarding.slide2.body"),
        Slide(systemImage: "chart.bar.doc.horizontal", titleKey: "onboarding.slide3.title", bodyKey: "onboarding.slide3.body"),
    ]

    var body: some View {
        VStack {
            TabView(selection: $page) {
                ForEach(Array(slides.enumerated()), id: \.offset) { idx, slide in
                    VStack(spacing: 24) {
                        Image(systemName: slide.systemImage)
                            .font(.system(size: 80))
                            .foregroundStyle(.tint)
                        Text(slide.titleKey)
                            .font(.title.bold())
                        Text(slide.bodyKey)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            PrimaryButton(
                title: page == slides.count - 1 ? "onboarding.start" : "onboarding.next",
                systemImage: page == slides.count - 1 ? "checkmark" : "arrow.left"
            ) {
                if page == slides.count - 1 {
                    onFinished()
                } else {
                    withAnimation { page += 1 }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private struct Slide {
        let systemImage: String
        let titleKey: LocalizedStringKey
        let bodyKey: LocalizedStringKey
    }
}
