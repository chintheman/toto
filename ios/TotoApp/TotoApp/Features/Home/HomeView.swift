import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()

    // MARK: - §6 Education state

    @State private var showOnboarding = false
    @State private var selectedMythIndex: Int?

    /// Shared myth data — matches OnboardingCarouselView exactly.
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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Amber error banner
                    if viewModel.showErrorBanner {
                        errorBanner
                    }

                    nextDrawCard
                    if let draw = viewModel.latestDraw {
                        latestResultCard(draw)
                        curatedFactsSection(for: draw)
                    }

                    // §6: Bust the Myths section
                    bustTheMythsSection
                }
                .padding()
            }
            .refreshable { await viewModel.load() }
            .navigationTitle("TOTO")
            .task { await viewModel.load() }
            .overlay {
                // Never-blank: loading overlay only when no cached data
                if viewModel.isLoading && viewModel.latestDraw == nil {
                    ProgressView()
                }
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingCarouselView(onFinished: {
                    showOnboarding = false
                })
            }
            .overlay {
                // Expanded myth card overlay
                if let idx = selectedMythIndex {
                    expandedMythCardOverlay(idx)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.25), value: selectedMythIndex)
                }
            }
        }
    }

    // MARK: - Error Banner

    private var errorBanner: some View {
        HStack(spacing: 10) {
            Text("⚠︎")
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.78, green: 0.47, blue: 0))
            Text("Couldn't refresh — showing results from \(viewModel.cacheAgeDescription ?? "earlier").")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color(red: 0.54, green: 0.35, blue: 0))
            Spacer()
            Button("Retry") {
                Task { await viewModel.retry() }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(red: 0.78, green: 0.47, blue: 0))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(11)
        .background(Color(red: 1.0, green: 0.95, blue: 0.90))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.96, green: 0.81, blue: 0.62), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Next Draw Card

    private var nextDrawCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Next Draw", systemImage: "calendar")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                // Cache age pill
                if let age = viewModel.cacheAgeDescription {
                    Text(age)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
            }

            if let upcoming = viewModel.upcomingDraw {
                Text(upcoming.drawDate, style: .date)
                    .font(.title2.bold())
                Text("Estimated jackpot: \(upcoming.estimatedJackpot, format: .currency(code: "SGD"))")
                    .font(.subheadline)
                if upcoming.isSnowball {
                    Text("Snowball draw").font(.caption).foregroundStyle(.orange)
                }
            } else {
                Text(viewModel.localNextDrawEstimate, style: .date)
                    .font(.title2.bold())
                Text("Jackpot amount unavailable — showing estimated schedule only")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Latest Result Card

    private func latestResultCard(_ draw: Draw) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Latest Result — Draw #\(draw.drawNumber)", systemImage: "checkmark.seal")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(draw.drawDate, style: .date)
                .font(.subheadline)

            HStack(spacing: 8) {
                ForEach(draw.winningNumbers, id: \.self) { number in
                    LotteryBallView(number: number, size: 40)
                }
                Text("+")
                    .foregroundStyle(.secondary)
                LotteryBallView(number: draw.additionalNumber, size: 40, isAdditional: true)
            }

            HStack {
                if draw.jackpotWon {
                    Text("Jackpot won this draw!")
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                } else {
                    Text("Jackpot rolled over")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
                Spacer()
                Text(draw.jackpotAmount, format: .currency(code: "SGD"))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Fun Facts Section

    private func curatedFactsSection(for draw: Draw) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Fun Facts About Today's Numbers", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(draw.winningNumbers + [draw.additionalNumber], id: \.self) { number in
                if let facts = viewModel.curatedFacts[number], let fact = facts.first {
                    HStack(alignment: .top, spacing: 12) {
                        LotteryBallView(number: number, size: 32)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(fact.headline).font(.subheadline.bold())
                            Text(fact.body).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Footer
            HStack(spacing: 4) {
                Text("Every number has a story — tap any ball in")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("History → Numbers")
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
                Text("for more.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Bust the Myths Section

    private var bustTheMythsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title row
            HStack {
                Label("Bust the Myths", systemImage: "lightbulb.max")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showOnboarding = true
                } label: {
                    Label("Replay", systemImage: "arrow.counterclockwise")
                        .font(.caption.bold())
                }
                .foregroundStyle(.blue)
            }

            // Myth rows
            ForEach(Array(myths.enumerated()), id: \.offset) { index, myth in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedMythIndex = index
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text(myth.emoji)
                            .font(.system(size: 22))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(myth.myth)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                                .foregroundStyle(.primary)

                            Text(myth.verdict)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.green)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Expanded Myth Card Overlay

    private func expandedMythCardOverlay(_ index: Int) -> some View {
        let myth = myths[index]

        return ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.043, green: 0.043, blue: 0.071),
                    Color(red: 0.169, green: 0.165, blue: 0.333)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: back button
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedMythIndex = nil
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("All myths")
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.blue)
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                // Myth card content (same layout as carousel pages)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 16)

                        // Tinted emoji circle + chip
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

                        // Myth quote — NO strikethrough
                        Text(myth.myth)
                            .font(.system(size: 24, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)

                        Spacer(minLength: 32)

                        // "THE TRUTH" divider line
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

                        // Green truth headline
                        Text(myth.truth)
                            .font(.system(size: 21, weight: .black))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.green)
                            .padding(.horizontal, 24)

                        Spacer(minLength: 12)

                        // Body text
                        Text(myth.body)
                            .font(.system(size: 15))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.horizontal, 28)

                        Spacer(minLength: 20)

                        // Mono stat chip
                        Text(myth.stat)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
