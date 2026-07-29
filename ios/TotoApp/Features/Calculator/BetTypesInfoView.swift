import SwiftUI

/// Marks the "Bet types explained" screen as a push destination from the
/// info row on the Budget card.
struct BetTypesDestination: Hashable {}

/// Pushed from Budget's "Ordinary, System 7 to 10 explained" info row.
/// Owns the bet-type education copy that used to live directly on the
/// Budget card (calculator-strategies handoff §2).
struct BetTypesInfoView: View {
    private struct BetTypeRow: Identifiable {
        let name: String
        let cost: String
        let description: String
        var id: String { name }
    }

    // Costs/combinations mirror EVMath.BetType.cost (C(numbersChosen, 6))
    // exactly — spelled out here rather than computed, since this screen
    // is pure copy, not a place to recompute the math.
    private let rows: [BetTypeRow] = [
        BetTypeRow(name: "Ordinary", cost: "$1", description: "Pick 6 numbers, 1 combination"),
        BetTypeRow(name: "System 7", cost: "$7", description: "Pick 7 numbers, covers 7 combinations"),
        BetTypeRow(name: "System 8", cost: "$28", description: "Pick 8 numbers, covers 28 combinations"),
        BetTypeRow(name: "System 9", cost: "$84", description: "Pick 9 numbers, covers 84 combinations"),
        BetTypeRow(name: "System 10", cost: "$210", description: "Pick 10 numbers, covers 210 combinations"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("THE FIVE BET TYPES")
                        .font(.system(size: 13))
                        .tracking(0.4)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 0) {
                        ForEach(rows.indices, id: \.self) { index in
                            if index > 0 { Divider() }
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(rows[index].name).font(.system(size: 17, weight: .bold))
                                    Spacer()
                                    Text(rows[index].cost)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.blue)
                                }
                                Text(rows[index].description)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("DOES THE BET TYPE CHANGE MY ODDS?")
                        .font(.system(size: 13))
                        .tracking(0.4)
                        .foregroundStyle(.secondary)

                    Text("You lose money at the same average rate either way, just spread out differently. Every $1 of combinations has the same odds, no matter which bet type it is packaged in. A System 10 just buys 210 of those combinations at once instead of 210 separate Ordinary lines.")
                        .font(.system(size: 15))
                        .lineSpacing(4)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Bet types")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        BetTypesInfoView()
    }
}
