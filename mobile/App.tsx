import { StatusBar } from "expo-status-bar";
import { useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { SafeAreaProvider, SafeAreaView } from "react-native-safe-area-context";
import { CalculatorScreen } from "./src/screens/CalculatorScreen";
import { EVScreen } from "./src/screens/EVScreen";
import { HomeScreen } from "./src/screens/HomeScreen";
import { MythsScreen } from "./src/screens/MythsScreen";
import { theme } from "./src/theme";

const TABS = [
  { key: "home", label: "Home", icon: "⢕", screen: HomeScreen },
  { key: "calc", label: "Calculator", icon: "🎯", screen: CalculatorScreen },
  { key: "ev", label: "EV Check", icon: "📈", screen: EVScreen },
  { key: "myths", label: "Myths", icon: "🔍", screen: MythsScreen },
] as const;

type TabKey = (typeof TABS)[number]["key"];

export default function App() {
  const [tab, setTab] = useState<TabKey>("home");
  const active = TABS.find(t => t.key === tab) ?? TABS[0];
  const Screen = active.screen;

  return (
    <SafeAreaProvider>
      <SafeAreaView style={styles.root} edges={["top", "bottom"]}>
        <View style={{ flex: 1 }}>
          <Screen />
        </View>
        <View style={styles.tabBar}>
          {TABS.map(t => {
            const isActive = t.key === tab;
            return (
              <Pressable key={t.key} style={styles.tabItem} onPress={() => setTab(t.key)}>
                <Text style={{ fontSize: 18, opacity: isActive ? 1 : 0.45 }}>{t.icon}</Text>
                <Text
                  style={{
                    fontSize: 10.5,
                    marginTop: 2,
                    fontWeight: isActive ? "700" : "500",
                    color: isActive ? theme.terracotta : theme.brownLight,
                  }}
                >
                  {t.label}
                </Text>
              </Pressable>
            );
          })}
        </View>
        <StatusBar style="dark" />
      </SafeAreaView>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.cream },
  tabBar: {
    flexDirection: "row",
    borderTopWidth: 1,
    borderTopColor: theme.beige,
    backgroundColor: theme.creamWarm,
    paddingTop: 8,
    paddingBottom: 4,
  },
  tabItem: { flex: 1, alignItems: "center" },
});
