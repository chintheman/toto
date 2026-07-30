import SwiftUI

/// Marks the "All Numbers" grid as a push destination distinct from the
/// reel — it's the one category tile that opens a plain scrollable grid
/// instead of the reel (see `AllNumbersGridView`).
struct AllNumbersGridDestination: Hashable {}

/// The Numbers tab's landing screen: an auto-rotating "Discover" hero card
/// plus a grid of category tiles. Deliberately no page title/description —
/// the hero card is the first thing on screen.
struct NumbersHubView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = NumbersHubViewModel()

    // MainTabView keeps every tab's view alive (opacity-toggled, never
    // removed) to preserve scroll/nav state across switches, so this is
    // the only signal the view model has for "is Numbers actually the
    // tab on screen right now" — used to pause the hero-card rotation
    // timer while it isn't, rather than letting it run forever.
    private var isActive: Bool { appState.selectedTab == .numbers }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroCard
                    categoryGrid
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 100)
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ReelDestination.self) { destination in
                NumberReelView(destination: destination)
            }
            .navigationDestination(for: AllNumbersGridDestination.self) { _ in
                AllNumbersGridView()
            }
            .overlay {
                if viewModel.isLoading && viewModel.spotlight == nil {
                    ProgressView()
                }
            }
            .task {
                await viewModel.load()
                viewModel.setActive(isActive)
            }
            .onChange(of: isActive) { _, newValue in
                viewModel.setActive(newValue)
            }
        }
    }

    @ViewBuilder
    private var heroCard: some View {
        if let spotlight = viewModel.spotlight {
            NavigationLink(value: ReelDestination.shuffled(category: spotlight.category, startingAt: spotlight.number)) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("✦ DISCOVER")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(.white.opacity(0.85))
                        Spacer()
                        HStack(spacing: 4) {
                            Circle().fill(.white).frame(width: 5, height: 5)
                            Circle().fill(.white.opacity(0.4)).frame(width: 5, height: 5)
                            Circle().fill(.white.opacity(0.4)).frame(width: 5, height: 5)
                        }
                    }
                    HStack(alignment: .center, spacing: 14) {
                        ZStack {
                            Circle().fill(.white.opacity(0.16))
                            Text("\(spotlight.number)")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 64, height: 64)
                        Text(spotlight.fact.headline)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(3)
                    }
                    HStack {
                        Text(spotlight.category.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.18), in: Capsule())
                        Spacer()
                        Text("Tap to explore ›")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(20)
                .background(
                    // "background tinted to that number's category color"
                    // — was hardcoded to Prime's teal for every spotlight.
                    LinearGradient(
                        colors: spotlight.category.reelBackground,
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 22)
                )
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.35), value: spotlight.number)
        }
    }

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BROWSE BY CATEGORY")
                .font(.system(size: 13))
                .tracking(0.4)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                ForEach(NumberCategory.allCases) { category in
                    if category == .allNumbers {
                        NavigationLink(value: AllNumbersGridDestination()) {
                            categoryTile(category)
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink(value: ReelDestination.shuffled(category: category, startingAt: category.numbers.randomElement() ?? 1)) {
                            categoryTile(category)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func categoryTile(_ category: NumberCategory) -> some View {
        let colors = category.tileGradient
        return VStack(alignment: .leading, spacing: 0) {
            Text(category.title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
            Spacer(minLength: 4)
            Text(category.tileSubtitle)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 92, maxHeight: 92, alignment: .topLeading)
        .background(
            colors.count > 1
                ? AnyShapeStyle(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                : AnyShapeStyle(colors[0]),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }
}
