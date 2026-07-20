import { useState } from "react";
import { ScrollView, StyleSheet, Text, View } from "react-native";
import { evAtJackpot, evByJackpot } from "../../shared/totoData";
import { Card, Chip, Heading, PrimaryButton, SubText } from "../components";
import { serif, theme } from "../theme";

const QUICK = [1, 2.5, 4.5, 6, 8, 10];

export function EVScreen() {
  const [jm, setJm] = useState(2.5);
  const ev = Math.round(evAtJackpot(jm));
  const positive = ev > 0;
  const verdictColor = positive ? theme.sage : theme.terracotta;

  return (
    <ScrollView contentContainerStyle={styles.container} showsVerticalScrollIndicator={false}>
      <Heading>Worth Playing?</Heading>
      <SubText>
        Expected Value (EV): for every $1 you spend, how much prize money comes back on average. Below ~$3.5M jackpot
        that's 30–50¢. Above $4.5M, more than $1.
      </SubText>

      <Card style={{ marginTop: 20, alignItems: "center" }}>
        <Text style={{ color: theme.brownLight, fontSize: 13 }}>Current jackpot</Text>
        <Text style={{ fontFamily: serif, fontSize: 44, fontWeight: "700", color: theme.brown, marginVertical: 4 }}>
          ${jm.toFixed(1)}M
        </Text>

        <View style={{ flexDirection: "row", gap: 10, marginVertical: 10 }}>
          <View style={{ flex: 1 }}>
            <PrimaryButton label="−$0.5M" variant="outline" onPress={() => setJm(v => Math.max(1, +(v - 0.5).toFixed(1)))} />
          </View>
          <View style={{ flex: 1 }}>
            <PrimaryButton label="+$0.5M" variant="outline" onPress={() => setJm(v => Math.min(12, +(v + 0.5).toFixed(1)))} />
          </View>
        </View>

        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6, justifyContent: "center" }}>
          {QUICK.map(q => (
            <Chip key={q} label={`$${q}M`} active={jm === q} onPress={() => setJm(q)} />
          ))}
        </View>

        <View style={[styles.verdict, { backgroundColor: `${verdictColor}15`, borderColor: `${verdictColor}40` }]}>
          <Text style={{ fontFamily: serif, fontSize: 30, fontWeight: "700", color: verdictColor }}>
            {positive ? "+" : ""}
            {ev}% EV
          </Text>
          <Text style={{ color: theme.brownLight, fontSize: 13, textAlign: "center", marginTop: 6, lineHeight: 19 }}>
            Every $1 played returns ≈ <Text style={{ fontWeight: "700", color: theme.brown }}>${(1 + ev / 100).toFixed(2)}</Text>{" "}
            on average.{"\n"}
            {positive ? "Positive EV — one of the rare draws worth playing." : "Paying for entertainment, not value. Wait for $4.5M+."}
          </Text>
        </View>
      </Card>

      <Text style={styles.sectionTitle}>The full table</Text>
      <Card>
        {evByJackpot.map(r => {
          const pos = r.ev > 0;
          return (
            <View key={r.jackpot} style={styles.barRow}>
              <Text style={{ width: 52, color: theme.brown, fontSize: 12, fontWeight: "600", textAlign: "right" }}>
                {r.jackpot}
              </Text>
              <View style={styles.barTrack}>
                <View
                  style={{
                    width: `${Math.round((100 + r.ev) / 2)}%`,
                    height: "100%",
                    borderRadius: 999,
                    backgroundColor: pos ? theme.sage : theme.beigeDark,
                  }}
                />
              </View>
              <Text style={{ width: 46, color: pos ? theme.sage : theme.brownLight, fontSize: 12, fontWeight: "600" }}>
                {pos ? "+" : "−"}
                {Math.abs(r.ev)}%
              </Text>
            </View>
          );
        })}
        <Text style={{ color: theme.brownLight, fontSize: 12, marginTop: 10 }}>
          <Text style={{ fontWeight: "700", color: theme.brown }}>Bottom line:</Text> wait for $4M+. Everything below that
          is expensive entertainment.
        </Text>
      </Card>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { padding: 20, paddingBottom: 40 },
  verdict: {
    alignItems: "center",
    borderRadius: 16,
    borderWidth: 1,
    marginTop: 16,
    padding: 16,
    alignSelf: "stretch",
  },
  sectionTitle: { fontFamily: serif, fontSize: 21, fontWeight: "700", color: theme.brown, marginTop: 24, marginBottom: 10 },
  barRow: { flexDirection: "row", alignItems: "center", gap: 8, paddingVertical: 5 },
  barTrack: { flex: 1, height: 14, borderRadius: 999, backgroundColor: theme.beige, overflow: "hidden" },
});
