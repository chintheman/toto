import SwiftUI

/// Marks the "Bet types explained" screen as a push destination from the
/// info row on the Budget card.
struct BetTypesDestination: Hashable {}

/// Pushed from Budget's "Ordinary, System 7 to 10 explained" info row.
/// Owns the bet-type education copy that used to live directly on the
/// Budget card (calculator-strategies handoff §2).
struct BetTypesInfoView: View {
    // Costs/combinations are derived from EVMath.BetType.cost (== C(numbers
    // Chosen, 6)) rather than a second hardcoded 1/7/28/84/210 — that enum
    // is the one place those numbers are allowed to live. BetType.allCases'
    // declared order (ordinary, system7...10) already matches the display
    // order this screen wants.
    private var rows: [BetType] { BetType.allCases }

    private func costLabel(_ type: BetType) -> String {
        "$\(Int(type.cost))"
    }

    private func description(_ type: BetType) -> String {
        let combinations = Int(type.cost)
        return type == .ordinary
            ? "Pick 6 numbers, 1 combination"
            : "Pick \(type.numbersChosen) numbers, covers \(combinations) combinations"
    }

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
                                    Text(rows[index].displayName).font(.system(size: 17, weight: .bold))
                                    Spacer()
                                    Text(costLabel(rows[index]))
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.blue)
                                }
                                Text(description(rows[index]))
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

                    Text("You lose money at the same average rate either way, just spread out differently. Every $1 of combinations has the same odds, no matter which bet type it is packaged in. A System 10 just buys \(Int(BetType.system10.cost)) of those combinations at once instead of \(Int(BetType.system10.cost)) separate Ordinary lines.")
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
        .floatingNavBarClearance()
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
