import SwiftUI

/// Design response §1: light, loud, Wrapped-style onboarding. One saturated
/// background per page, dark ink type, a flat-shape vignette that proves each
/// myth, a marker-highlighted truth line, and a full-width CTA. Skippable;
/// the same myths live on in the Learn tab.
struct OnboardingCarouselView: View {
    let onFinished: () -> Void

    @State private var fallacies: [Fallacy] = []
    @State private var currentPage = 0
    @State private var isLoading = true
    @State private var loadError: String?

    private let repository: FallaciesRepository

    init(repository: FallaciesRepository = FallaciesRepository(), onFinished: @escaping () -> Void) {
        self.repository = repository
        self.onFinished = onFinished
    }

    private var palette: CarouselPalette { CarouselPalette.page(currentPage) }

    var body: some View {
        ZStack {
            palette.bg
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.45), value: currentPage)

            softCircles

            if isLoading {
                ProgressView().tint(palette.ink)
            } else if let loadError {
                loadFailure(loadError)
            } else {
                content
            }
        }
        .task { await load() }
    }

    private var softCircles: some View {
        ZStack {
            Circle().fill(.white.opacity(0.3)).frame(width: 230, height: 230)
                .offset(x: -150, y: -360)
            Circle().fill(.white.opacity(0.3)).frame(width: 170, height: 170)
                .offset(x: 160, y: 230)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.45), value: currentPage)
    }

    private var content: some View {
        VStack(spacing: 0) {
            progressBar
            header
            TabView(selection: $currentPage) {
                ForEach(Array(fallacies.enumerated()), id: \.element.id) { index, fallacy in
                    CarouselPage(fallacy: fallacy, index: index, palette: CarouselPalette.page(index))
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            footer
        }
    }

    private var progressBar: some View {
        HStack(spacing: 5) {
            ForEach(fallacies.indices, id: \.self) { index in
                Capsule()
                    .fill(index <= currentPage ? palette.ink : .black.opacity(0.15))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .animation(.easeInOut(duration: 0.3), value: currentPage)
    }

    private var header: some View {
        HStack {
            Text("MYTH \(currentPage + 1) / \(fallacies.count)")
                .font(.caption.weight(.heavy))
                .tracking(1.5)
                .foregroundStyle(palette.bg)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(palette.ink, in: Capsule())
                .fixedSize()
            Spacer()
            Button("Skip") { onFinished() }
                .font(.subheadline)
                .foregroundStyle(palette.ink.opacity(0.55))
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .animation(.easeInOut(duration: 0.3), value: currentPage)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                if currentPage < fallacies.count - 1 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { currentPage += 1 }
                } else {
                    onFinished()
                }
            } label: {
                Text(currentPage == fallacies.count - 1 ? "Done" : "Next myth")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(palette.ink, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(palette.bg)
            }
            Text("Review these anytime in the Learn tab")
                .font(.caption2)
                .foregroundStyle(palette.ink.opacity(0.45))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .animation(.easeInOut(duration: 0.3), value: currentPage)
    }

    private func loadFailure(_ message: String) -> some View {
        VStack(spacing: 16) {
            Text("Couldn't load").font(.headline).foregroundStyle(palette.ink)
            Text(message).font(.caption).foregroundStyle(palette.ink.opacity(0.7)).multilineTextAlignment(.center)
            Button("Retry") { Task { await load() } }.buttonStyle(.bordered).tint(palette.ink)
            Button("Continue anyway") { onFinished() }.buttonStyle(.borderedProminent).tint(palette.ink)
        }
        .padding()
    }

    private func load() async {
        isLoading = true
        loadError = nil
        do {
            fallacies = try await repository.onboardingFallacies()
            if fallacies.isEmpty { loadError = "No content available yet." }
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}

/// One carousel page: vignette, myth, marker-highlighted truth, body, stat.
private struct CarouselPage: View {
    let fallacy: Fallacy
    let index: Int
    let palette: CarouselPalette

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 8)

            MythVignette(index: index, palette: palette)
                .frame(height: 150)

            Text(fallacy.mythStatement)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.center)

            MarkerText(text: fallacy.truthHeadline, ink: palette.ink)

            Text(fallacy.explanationBody)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.ink.opacity(0.75))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            if let stat = fallacy.statCallout {
                Text(stat)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.55), in: Capsule())
                    .overlay(Capsule().stroke(palette.ink, lineWidth: 2))
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 28)
    }
}

/// The truth line with a highlighter-marker behind its lower portion.
private struct MarkerText: View {
    let text: String
    let ink: Color

    var body: some View {
        Text(text)
            .font(.system(size: 34, weight: .black))
            .foregroundStyle(ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 6)
            .background(
                GeometryReader { geo in
                    // Highlighter stripe: white at 85% over the bottom 38%.
                    Rectangle()
                        .fill(.white.opacity(0.85))
                        .frame(height: geo.size.height * 0.38)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            )
    }
}

// MARK: - Vignettes (flat shapes, no image assets)

private struct MythVignette: View {
    let index: Int
    let palette: CarouselPalette

    var body: some View {
        switch index {
        case 0: HotNumberVignette(palette: palette)
        case 1: OverdueVignette(palette: palette)
        case 2: BirthdayVignette(palette: palette)
        case 3: PatternVignette(palette: palette)
        default: MoreTicketsVignette(palette: palette)
        }
    }
}

private func inkBall(_ label: String, palette: CarouselPalette, size: CGFloat = 40) -> some View {
    ZStack {
        Circle().fill(palette.ink)
        Text(label).font(.system(size: size * 0.4, weight: .bold)).foregroundStyle(palette.bg)
    }
    .frame(width: size, height: size)
}

private func openBall(_ label: String, palette: CarouselPalette, size: CGFloat = 40) -> some View {
    ZStack {
        Circle().fill(.white)
        Circle().stroke(palette.ink, lineWidth: 2)
        Text(label).font(.system(size: size * 0.4, weight: .bold)).foregroundStyle(palette.ink)
    }
    .frame(width: size, height: size)
}

private func equalsSign(_ palette: CarouselPalette) -> some View {
    Text("=").font(.system(size: 28, weight: .heavy)).foregroundStyle(palette.ink.opacity(0.6))
}

private struct HotNumberVignette: View {
    let palette: CarouselPalette
    var body: some View {
        HStack(spacing: 8) {
            inkBall("8", palette: palette)
            inkBall("8", palette: palette)
            inkBall("8", palette: palette)
            equalsSign(palette)
            ZStack {
                Circle().fill(.white.opacity(0.7))
                Circle().stroke(style: StrokeStyle(lineWidth: 3, dash: [5, 4])).foregroundStyle(palette.ink)
                Text("?").font(.system(size: 18, weight: .bold)).foregroundStyle(palette.ink)
            }
            .frame(width: 40, height: 40)
        }
    }
}

private struct OverdueVignette: View {
    let palette: CarouselPalette
    private let columns = Array(repeating: GridItem(.fixed(16), spacing: 8), count: 8)
    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(0..<24, id: \.self) { i in
                if i == 12 {
                    Circle().stroke(style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])).foregroundStyle(palette.ink)
                        .frame(width: 16, height: 16)
                } else {
                    Circle().fill(palette.ink).frame(width: 16, height: 16)
                }
            }
        }
        .frame(width: 8 * 16 + 7 * 8)
    }
}

private struct BirthdayVignette: View {
    let palette: CarouselPalette
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: -14) {
                ForEach(0..<9, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(palette.ink.opacity(0.85))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.bg, lineWidth: 2))
                        .frame(width: 24, height: 32)
                }
            }
            Text("1–31: everyone's birthday · 32–49: room to breathe")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(palette.ink.opacity(0.7))
        }
    }
}

private struct PatternVignette: View {
    let palette: CarouselPalette
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                ForEach([1, 2, 3, 4, 5, 6], id: \.self) { inkBall("\($0)", palette: palette, size: 30) }
            }
            equalsSign(palette)
            HStack(spacing: 5) {
                ForEach([7, 19, 23, 31, 40, 44], id: \.self) { openBall("\($0)", palette: palette, size: 30) }
            }
        }
    }
}

private struct MoreTicketsVignette: View {
    let palette: CarouselPalette
    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 8).fill(palette.ink).frame(width: 44, height: 58)
                Text("58¢ / $1").font(.system(size: 12, weight: .bold)).foregroundStyle(palette.ink)
            }
            Text("=").font(.system(size: 22, weight: .heavy)).foregroundStyle(palette.ink).padding(.bottom, 22)
            VStack(spacing: 6) {
                HStack(spacing: -26) {
                    ForEach(0..<5, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(palette.ink.opacity(0.85))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.bg, lineWidth: 2))
                            .frame(width: 44, height: 58)
                    }
                }
                Text("still 58¢ / $1").font(.system(size: 12, weight: .bold)).foregroundStyle(palette.ink)
            }
        }
    }
}

/// Design response §2/§4: the dark "focus mode" myth card used in Learn.
struct MythDetailCard: View {
    let fallacy: Fallacy

    private let cardColor = Color(hex: 0x0A0A10)

    var body: some View {
        let style = fallacy.style
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.08))
                    Image(systemName: style.symbol).font(.footnote).foregroundStyle(style.tint)
                }
                .frame(width: 30, height: 30)
                if let category = fallacy.category {
                    Text(category)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(style.tint)
                        .lineLimit(2)
                }
            }

            Text(fallacy.mythStatement)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.top, 16)

            RoundedRectangle(cornerRadius: 2)
                .fill(CategoryStyle.truthGreen)
                .frame(width: 44, height: 3)
                .padding(.top, 22)
                .padding(.bottom, 12)

            Text(fallacy.truthHeadline)
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(CategoryStyle.truthGreen)

            Text(fallacy.explanationBody)
                .font(.subheadline)
                .lineSpacing(4)
                .foregroundStyle(.white.opacity(0.62))
                .padding(.top, 10)

            if let stat = fallacy.statCallout {
                HStack(spacing: 6) {
                    Text("◆").foregroundStyle(style.tint)
                    Text(stat).foregroundStyle(.white.opacity(0.75))
                }
                .font(.caption.monospaced())
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(.white.opacity(0.06), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.1)))
                .padding(.top, 18)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 26)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(cardColor)
                RadialGradient(colors: [style.tint.opacity(0.35), .clear],
                               center: UnitPoint(x: 0.5, y: -0.1), startRadius: 0, endRadius: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        )
    }
}
