import SwiftUI

/// The one category tile that breaks the hub's reel pattern: a plain
/// scrollable grid of all 49, pushed from the "All Numbers" tile. Tapping
/// a ball jumps straight into the reel at that number, in natural 1...49
/// order (not shuffled — this is a deliberate, ordered browse, unlike the
/// hub's other category tiles).
struct AllNumbersGridView: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Every number from 1 to 49. Tap one for its story.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(1...49, id: \.self) { number in
                        NavigationLink(value: ReelDestination.sequential(startingAt: number)) {
                            LotteryBallView(number: number, size: 56)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("All Numbers")
        .navigationBarTitleDisplayMode(.inline)
    }
}
