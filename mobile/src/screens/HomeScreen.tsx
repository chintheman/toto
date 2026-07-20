import { useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import { funFacts, type Accent } from "../../shared/content";
import { Card, Heading, SubText } from "../components";
import { serif, theme } from "../theme";
import { useNextDraw } from "../useNextDraw";

const accentColor: Record<Accent, string> = {
  terracotta: theme.terracotta,
  sage: theme.sage,
  brownLight: theme.brownLight,
};

function FactCard({ fact }: { fact: (typeof funFacts)[number] }) {
  const [flipped, setFlipped] = useState(false);
  const color = accentColor[fact.accent];
  return (
    <Pressable onPress={() => setFlipped(f => !f)} style={styles.factCard}>
      {!flipped ? (
        <>
          <Text style={{ fontSize: 22 }}>{fact.emoji}</Text>
          <Text style={{ fontFamily: serif, fontSize: 19, fontWeight: "700", color, marginTop: 6 }}>{fact.stat}</Text>
          <Text style={{ color: theme.brown, fontSize: 13, fontWeight: "600", marginTop: 4 }}>{fact.label}</Text>
          <Text style={{ color: theme.brownLight, fontSize: 11, marginTop: 8 }}>tap to find out why →</Text>
        </>
      ) : (
        <>
          <Text style={{ fontFamily: serif, fontSize: 15, fontWeight: "700", color }}>{fact.n}</Text>
          <Text style={{ color: theme.brownLight, fontSize: 12.5, lineHeight: 18, marginTop: 6 }}>{fact.detail}</Text>
          <Text style={{ color: theme.brownLight, fontSize: 11, marginTop: 8 }}>← tap to flip back</Text>
        </>
      )}
    </Pressable>
  );
}

export function HomeScreen() {
  const draw = useNextDraw();
  return (
    <ScrollView contentContainerStyle={styles.container} showsVerticalScrollIndicator={false}>
      <Text style={styles.kicker}>1,000+ DRAWS OF DATA</Text>
      <Heading>TOTO Strategy</Heading>
      <Text style={[styles.headingAccent]}>Without the Nonsense</Text>
      <SubText>Every myth busted with real data. Know the math before you spend a cent.</SubText>

      <Card style={{ marginTop: 20 }}>
        <View style={{ flexDirection: "row", alignItems: "center", gap: 8 }}>
          <View style={styles.liveDot} />
          <Text style={{ color: theme.terracotta, fontWeight: "600", fontSize: 13 }}>NEXT DRAW</Text>
        </View>
        <Text style={{ fontFamily: serif, fontSize: 24, fontWeight: "700", color: theme.brown, marginTop: 8 }}>
          {draw.day} {draw.date}
        </Text>
        <Text style={{ color: theme.brownLight, fontSize: 14, marginTop: 4 }}>
          Jackpot: <Text style={{ color: theme.terracotta, fontWeight: "700" }}>{draw.jackpot}</Text> · 6:30pm SGT
        </Text>
      </Card>

      <Text style={styles.sectionTitle}>What the numbers actually say</Text>
      <SubText>Randomness creates fascinating quirks. None are exploitable — all are interesting.</SubText>
      <View style={styles.factGrid}>
        {funFacts.map(fact => (
          <FactCard key={fact.n} fact={fact} />
        ))}
      </View>

      <Text style={styles.footer}>The draw is fair. No strategy guarantees a win. Play responsibly.</Text>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { padding: 20, paddingBottom: 40 },
  kicker: { color: theme.brownLight, fontSize: 11, letterSpacing: 2, marginBottom: 8 },
  headingAccent: { fontFamily: serif, fontSize: 28, fontWeight: "700", letterSpacing: -0.5, color: theme.terracotta, marginTop: -4, marginBottom: 10 },
  liveDot: { width: 8, height: 8, borderRadius: 4, backgroundColor: theme.terracotta },
  sectionTitle: { fontFamily: serif, fontSize: 21, fontWeight: "700", color: theme.brown, marginTop: 28, marginBottom: 6 },
  factGrid: { flexDirection: "row", flexWrap: "wrap", gap: 10, marginTop: 14 },
  factCard: {
    backgroundColor: theme.creamWarm,
    borderColor: theme.beige,
    borderWidth: 1,
    borderRadius: 16,
    padding: 14,
    width: "48%",
    flexGrow: 1,
    minHeight: 130,
  },
  footer: { color: theme.brownLight, fontSize: 11, textAlign: "center", marginTop: 32 },
});
