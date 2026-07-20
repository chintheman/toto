import { useEffect, useMemo, useState } from "react";
import { ScrollView, Share, StyleSheet, Text, View } from "react-native";
import { strats } from "../../shared/totoData";
import { generatePortfolio, type StrategyKey } from "../../shared/ticketGenerator";
import { Ball, Card, Chip, Heading, PrimaryButton, SubText } from "../components";
import { serif, theme } from "../theme";

const BUDGETS = [20, 50, 100, 200, 500];
const GOALS: { key: StrategyKey; label: string }[] = [
  { key: "1k", label: "Any prize" },
  { key: "100k", label: "~$100K" },
  { key: "mega", label: "Jackpot" },
];

export function CalculatorScreen() {
  const [budget, setBudget] = useState(100);
  const [goal, setGoal] = useState<StrategyKey>("1k");
  const [showTickets, setShowTickets] = useState(false);
  const [seed, setSeed] = useState(() => Date.now() % 1_000_000);

  useEffect(() => setShowTickets(false), [goal]);

  const s = strats[goal];
  const ok = budget >= s.cost;
  const portfolio = useMemo(
    () => (showTickets && ok ? generatePortfolio(goal, seed) : null),
    [showTickets, ok, goal, seed]
  );

  const shareTickets = () => {
    if (!portfolio) return;
    const lines = portfolio.tickets.map(
      t => `${t.type === "S7" ? "System 7" : "Ordinary"}: ${t.numbers.join(" ")}`
    );
    Share.share({ message: `My TOTO tickets (${s.name}, $${s.cost}):\n${lines.join("\n")}` }).catch(() => {});
  };

  return (
    <ScrollView contentContainerStyle={styles.container} showsVerticalScrollIndicator={false}>
      <Heading>Run Your Numbers</Heading>
      <SubText>Pick your budget and your goal. The strategy adjusts automatically.</SubText>

      <Text style={styles.label}>How much do you want to spend?</Text>
      <View style={styles.chipRow}>
        {BUDGETS.map(b => (
          <Chip key={b} label={`$${b}`} active={budget === b} onPress={() => setBudget(b)} />
        ))}
      </View>

      <Text style={styles.label}>What are you hoping to win?</Text>
      <View style={styles.chipRow}>
        {GOALS.map(g => (
          <Chip key={g.key} label={g.label} active={goal === g.key} onPress={() => setGoal(g.key)} />
        ))}
      </View>

      <Card style={{ marginTop: 20 }}>
        <Text style={{ fontFamily: serif, fontSize: 22, fontWeight: "700", color: theme.brown }}>{s.name}</Text>
        <Text style={{ color: theme.brownLight, fontSize: 13, marginTop: 2 }}>{s.tag}</Text>

        {!ok ? (
          <View style={styles.warning}>
            <Text style={{ color: theme.brownLight, fontSize: 13.5, lineHeight: 20 }}>
              This strategy needs a <Text style={{ fontWeight: "700", color: theme.brown }}>${s.cost} minimum</Text>. Bump up
              your spend, or pick a different goal.
            </Text>
          </View>
        ) : (
          <>
            <View style={styles.statGrid}>
              {[
                { v: s.any, label: "Win anything", color: theme.terracotta },
                { v: s.g3, label: "Win ~$1,000", color: theme.sage },
                { v: s.g2, label: "Win ~$100,000", color: theme.brownLight },
                { v: s.g1, label: "Win jackpot", color: theme.terracotta },
              ].map(item => (
                <View key={item.label} style={styles.statBox}>
                  <Text style={{ fontFamily: serif, fontSize: 17, fontWeight: "700", color: item.color }}>{item.v}</Text>
                  <Text style={{ color: theme.brownLight, fontSize: 11, marginTop: 2 }}>{item.label}</Text>
                </View>
              ))}
            </View>
            <Text style={{ color: theme.brownLight, fontSize: 13, marginTop: 14 }}>
              <Text style={{ fontWeight: "700", color: theme.brown }}>Method:</Text> {s.m}
            </Text>
            <Text style={{ color: theme.brownLight, fontSize: 13, marginTop: 6 }}>
              <Text style={{ fontWeight: "700", color: theme.brown }}>Best when:</Text> {s.w}
            </Text>

            {!portfolio && (
              <View style={{ marginTop: 16 }}>
                <PrimaryButton label="🎟  Generate my tickets" onPress={() => setShowTickets(true)} />
              </View>
            )}
          </>
        )}
      </Card>

      {portfolio && (
        <Card style={{ marginTop: 14 }}>
          <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
            <View>
              <Text style={{ fontFamily: serif, fontSize: 18, fontWeight: "700", color: theme.brown }}>Your tickets</Text>
              <Text style={{ color: theme.brownLight, fontSize: 11, marginTop: 2 }}>
                Mean overlap: {portfolio.meanOverlap.toFixed(2)} numbers
              </Text>
            </View>
          </View>

          {portfolio.pool && (
            <View style={{ marginTop: 12 }}>
              <Text style={{ color: theme.brownLight, fontSize: 12, marginBottom: 6 }}>Your 14-number pool:</Text>
              <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
                {portfolio.pool.map(n => (
                  <Ball key={n} n={n} size={26} color={theme.brownLight} />
                ))}
              </View>
            </View>
          )}

          <View style={{ marginTop: 12, gap: 8 }}>
            {portfolio.tickets.map((t, i) => (
              <View key={i} style={styles.ticketRow}>
                <Text
                  style={{
                    width: 34,
                    fontSize: 10,
                    fontWeight: "700",
                    color: t.type === "S7" ? theme.sage : theme.terracotta,
                  }}
                >
                  {t.type}
                </Text>
                <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5, flex: 1 }}>
                  {t.numbers.map(n => (
                    <Ball key={n} n={n} size={26} color={t.type === "S7" ? theme.sage : theme.terracotta} />
                  ))}
                </View>
              </View>
            ))}
          </View>

          <View style={{ flexDirection: "row", gap: 10, marginTop: 16 }}>
            <View style={{ flex: 1 }}>
              <PrimaryButton label="🎲 Shuffle" variant="outline" onPress={() => setSeed(v => v + 1)} />
            </View>
            <View style={{ flex: 1 }}>
              <PrimaryButton label="Share" onPress={shareTickets} />
            </View>
          </View>

          <Text style={{ color: theme.brownLight, fontSize: 11, textAlign: "center", marginTop: 12 }}>
            Random low-overlap numbers — every set has identical odds. Shuffling doesn't improve them.
          </Text>
        </Card>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { padding: 20, paddingBottom: 40 },
  label: { color: theme.brown, fontSize: 14, fontWeight: "600", marginTop: 20, marginBottom: 10 },
  chipRow: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  warning: {
    backgroundColor: `${theme.terracotta}12`,
    borderRadius: 12,
    padding: 12,
    marginTop: 14,
  },
  statGrid: { flexDirection: "row", flexWrap: "wrap", gap: 8, marginTop: 14 },
  statBox: {
    backgroundColor: theme.cream,
    borderColor: theme.beige,
    borderWidth: 1,
    borderRadius: 12,
    padding: 10,
    alignItems: "center",
    width: "48%",
    flexGrow: 1,
  },
  ticketRow: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: theme.cream,
    borderColor: theme.beige,
    borderWidth: 1,
    borderRadius: 12,
    paddingHorizontal: 10,
    paddingVertical: 7,
  },
});
