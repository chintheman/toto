import type { ReactNode } from "react";
import { Pressable, StyleSheet, Text, View, type ViewStyle } from "react-native";
import { serif, theme } from "./theme";

export function Ball({ n, size = 32, color = theme.terracotta }: { n: number | string; size?: number; color?: string }) {
  return (
    <View
      style={{
        width: size,
        height: size,
        borderRadius: size / 2,
        backgroundColor: color,
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      <Text style={{ color: "#fff", fontFamily: serif, fontWeight: "700", fontSize: size * 0.42 }}>{n}</Text>
    </View>
  );
}

export function Card({ children, style }: { children: ReactNode; style?: ViewStyle }) {
  return <View style={[styles.card, style]}>{children}</View>;
}

export function Heading({ children, color = theme.brown }: { children: ReactNode; color?: string }) {
  return <Text style={[styles.heading, { color }]}>{children}</Text>;
}

export function SubText({ children }: { children: ReactNode }) {
  return <Text style={styles.subText}>{children}</Text>;
}

export function Chip({ label, active, onPress }: { label: string; active: boolean; onPress: () => void }) {
  return (
    <Pressable
      onPress={onPress}
      style={[
        styles.chip,
        active
          ? { backgroundColor: theme.terracotta, borderColor: theme.terracotta }
          : { backgroundColor: theme.cream, borderColor: theme.beigeDark },
      ]}
    >
      <Text style={{ color: active ? "#fff" : theme.brownLight, fontSize: 14, fontWeight: "600" }}>{label}</Text>
    </Pressable>
  );
}

export function PrimaryButton({ label, onPress, variant = "solid" }: { label: string; onPress: () => void; variant?: "solid" | "outline" }) {
  return (
    <Pressable
      onPress={onPress}
      style={[
        styles.button,
        variant === "solid"
          ? { backgroundColor: theme.terracotta }
          : { backgroundColor: theme.cream, borderWidth: 1, borderColor: theme.beigeDark },
      ]}
    >
      <Text style={{ color: variant === "solid" ? "#fff" : theme.brownLight, fontSize: 15, fontWeight: "600" }}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: theme.creamWarm,
    borderColor: theme.beige,
    borderWidth: 1,
    borderRadius: 20,
    padding: 18,
  },
  heading: {
    fontFamily: serif,
    fontSize: 28,
    fontWeight: "700",
    letterSpacing: -0.5,
    marginBottom: 6,
  },
  subText: {
    color: theme.brownLight,
    fontSize: 14,
    lineHeight: 21,
  },
  chip: {
    paddingHorizontal: 16,
    paddingVertical: 9,
    borderRadius: 999,
    borderWidth: 1,
  },
  button: {
    alignItems: "center",
    paddingVertical: 13,
    borderRadius: 999,
  },
});
