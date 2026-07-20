import SwiftUI

/// Hardcoded 5-myth educational carousel — replaces the old Supabase-backed
/// 19-fallacy flow. Shown once on first launch (gated by
/// AppState.hasCompletedOnboarding) and replayable from Home.
struct OnboardingCarouselView: View {
    let onFinished: () -> Void

    @State private var currentPage = 0

    private let myths: [(emoji: String, tint: Color, myth: String, truth: String, verdict: String, body: String, stat: String)] = [
        ("🔥", Color(red: 1, green: 0.54, blue: 0.40, opacity: 0.18),
         "\"Number 8 is hot right now, so it's bound to keep hitting.\"",
         "Balls have no memory.",
         "Busted: balls have no memory",
         "Every draw starts from scratch. A number that hit three weeks in a row is exactly as likely as any other number in the next draw.",
         "P(any number) = 6/49 in every draw"),
        ("⏰", Color(red: 0.51, green: 0.83, blue: 0.98, opacity: 0.16),
         "\"13 hasn't come up in months, so it's overdue.\"",
         "Nothing is ever overdue.",
         "Busted: the gambler's fallacy",
         "The machine doesn't owe anyone a number. \"Overdue\" numbers hit at the same rate as every other number.",
         "Absences of 20+ draws happen by pure chance"),
        ("🎂", Color(red: 0.96, green: 0.56, blue: 0.69, opacity: 0.16),
         "\"My birthday numbers are luckier for me.\"",
         "Same odds, worse payout.",
         "Busted: they cost you more",
         "Birthdays only reach 31, and millions of players pick them. If they win, you share the prize with a bigger crowd.",
         "Numbers 32 to 49 are picked about 40% less often"),
        ("📊", Color(red: 0.70, green: 0.62, blue: 0.86, opacity: 0.18),
         "\"A pattern like all even numbers can't win.\"",
         "Every combination is equal.",
         "Busted: every combo is equal",
         "The sequence 1, 2, 3, 4, 5, 6 is precisely as likely as any random-looking spread. Patterns feel wrong; the math disagrees.",
         "All 13,983,816 combinations have identical odds"),
        ("💸", Color(red: 1, green: 0.84, blue: 0.31, opacity: 0.16),
         "\"Buy more tickets and you'll come out ahead.\"",
         "Losses scale with spend.",
         "Busted: losses scale too",
         "More tickets means more chances and proportionally more spend. The return per dollar never improves.",
         "Return is about 58 cents per $1, at any volume")
    ]

    var body: some View {
        ZStack {
            // Dark gradient
            LinearGradient(
                colors: [
                    Color(red: 0.043, green: 0.043, blue: 0.071),  // #0B0B12
                    Color(red: 0.169, green: 0.165, blue: 0.333)   // #2B2A55
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // --- Top bar: segmented progress + Skip ---
                HStack(alignment: .center) {
                    MythSegmentedBar(segments: myths.count, currentPage: currentPage)
                        .frame(height: 4)

                    Text("MYTH \(currentPage + 1) OF \(myths.count)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 90)

                    Button("Skip") {
                        onFinished()
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 20)
                .padding(.top, safeAreaTop())

                // --- Page content ---
                TabView(selection: $currentPage) {
                    ForEach(Array(myths.enumerated()), id: \.offset) { index, myth in
                        MythPageView(myth: myth)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .padding(.top, 4)

                // --- Footer ---
                VStack(spacing: 6) {
                    Button {
                        onFinished()
                    } label: {
                        Text(currentPage == myths.count - 1 ? "Done" : "Next myth")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 20)

                    Text("Review these anytime in the Learn tab")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.bottom, 8)
                }
                .padding(.bottom, safeAreaBottom())
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Safe area helpers

    private func safeAreaTop() -> CGFloat {
        // TabView + status bar overhead — minimum 12
        12
    }

    private func safeAreaBottom() -> CGFloat {
        // Bottom safe area for home indicator
        #if os(iOS)
        return UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.safeAreaInsets.bottom ?? 16
        #else
        return 16
        #endif
    }
}

// MARK: - Myth Segmented Bar

struct MythSegmentedBar: View {
    let segments: Int
    let currentPage: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0 ..< segments, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= currentPage ? Color.white : Color.white.opacity(0.2))
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Single Myth Page

struct MythPageView: View {
    let myth: (emoji: String, tint: Color, myth: String, truth: String, verdict: String, body: String, stat: String)

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer(minLength: 16)

                // 1. Tinted emoji circle + "THE MYTH" chip
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(myth.tint)
                            .frame(width: 52, height: 52)
                        Text(myth.emoji)
                            .font(.system(size: 28))
                    }

                    Text("THE MYTH")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.red.opacity(0.15))
                        .clipShape(Capsule())
                }

                Spacer(minLength: 24)

                // 2. Myth quote — NO strikethrough
                Text(myth.myth)
                    .font(.system(size: 24, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)

                Spacer(minLength: 32)

                // 3. "THE TRUTH" divider line
                HStack {
                    VStack { Divider().background(.green) }
                    Text("THE TRUTH")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                    VStack { Divider().background(.green) }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 16)

                // 4. Green truth headline
                Text(myth.truth)
                    .font(.system(size: 21, weight: .black))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 24)

                Spacer(minLength: 12)

                // 5. Body text
                Text(myth.body)
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 28)

                Spacer(minLength: 20)

                // 6. Mono stat chip
                Text(myth.stat)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Legacy Fallacy card (reused by LearnView)

struct FallacyCardView: View {
    let fallacy: Fallacy

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text(fallacy.emoji ?? "🎲")
                .font(.system(size: 64))

            Text(fallacy.mythStatement)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            Text(fallacy.verdictLabel.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.green.opacity(0.2), in: Capsule())

            Text(fallacy.explanationBody)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 32)

            if let stat = fallacy.statCallout {
                Text(stat)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()
            Spacer()
        }
        .padding()
    }
}

#Preview {
    OnboardingCarouselView(onFinished: {})
}
