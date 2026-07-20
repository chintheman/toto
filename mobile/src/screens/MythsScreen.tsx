import { ScrollView, StyleSheet, Text, View } from "react-native";
import { myths } from "../../shared/content";
import { Card, Heading, SubText } from "../components";
import { theme } from "../theme";

export function MythsScreen() {
  return (
    <ScrollView contentContainerStyle={styles.container} showsVerticalScrollIndicator={false}>
      <Heading>7 Things People Believe</Heading>
      <Text style={styles.headingAccent}>That Are Simply Wrong</Text>
      <SubText>Lottery folklore doesn't survive contact with data. Here's what 1,000+ draws actually show.</SubText>

      <View style={{ gap: 12, marginTop: 20 }}>
        {myths.map(myth => (
          <Card key={myth.m}>
            <View style={{ flexDirection: "row", gap: 10 }}>
              <Text style={{ fontSize: 20 }}>{myth.e}</Text>
              <View style={{ flex: 1 }}>
                <Text style={styles.mythClaim}>{myth.m}</Text>
                <View style={styles.verdictPill}>
                  <Text style={{ color: theme.sage, fontSize: 11, fontWeight: "600" }}>✓ {myth.verdict}</Text>
                </View>
                <Text style={{ color: theme.brownLight, fontSize: 13.5, lineHeight: 20, marginTop: 8 }}>{myth.t}</Text>
              </View>
            </View>
          </Card>
        ))}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { padding: 20, paddingBottom: 40 },
  headingAccent: {
    fontFamily: "Georgia",
    fontSize: 28,
    fontWeight: "700",
    letterSpacing: -0.5,
    color: theme.sage,
    marginTop: -4,
    marginBottom: 10,
  },
  mythClaim: {
    color: theme.brown,
    fontSize: 14.5,
    fontWeight: "600",
    textDecorationLine: "line-through",
    opacity: 0.55,
  },
  verdictPill: {
    alignSelf: "flex-start",
    backgroundColor: `${theme.sage}18`,
    borderRadius: 999,
    paddingHorizontal: 9,
    paddingVertical: 3,
    marginTop: 6,
  },
});
