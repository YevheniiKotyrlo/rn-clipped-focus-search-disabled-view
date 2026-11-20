/**
 * Twenty Pressable rows in a 300-point ScrollView, row 12 disabled, and a button below the list. Opened with
 * rnrepro://clipped (or with no URL) the ScrollView sets removeClippedSubviews; opened with rnrepro://unclipped it
 * does not. With a hardware keyboard, Tab from row 11 should go to row 13 in both.
 *
 * @format
 */

import { useEffect, useState } from 'react';
import {
  Linking,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';

// React Native's own accessor for the native feature flag, read to show the value the app runs with.
const { enableCustomFocusSearchOnClippedElementsAndroid } =
  require('react-native/src/private/featureflags/ReactNativeFeatureFlags') as {
    enableCustomFocusSearchOnClippedElementsAndroid: () => boolean;
  };

const rowCount = 20;
const disabledRow = 12;

// Each Pressable sits in a View of its own rather than directly in the ScrollView's content, which the clipped-element
// focus search does not reach on main (react/react-native#59073).
function Row({
  label,
  disabled,
}: {
  readonly label: string;
  readonly disabled?: boolean;
}) {
  const [focused, setFocused] = useState(false);
  return (
    <View collapsable={false} style={styles.rowWrapper}>
      <Pressable
        accessibilityLabel={label}
        disabled={disabled}
        onPress={() => {}}
        onFocus={() => setFocused(true)}
        onBlur={() => setFocused(false)}
        style={[
          styles.row,
          disabled && styles.disabled,
          focused && styles.focused,
        ]}
      >
        <Text style={styles.rowText}>{label}</Text>
      </Pressable>
    </View>
  );
}

function App() {
  const [clipped, setClipped] = useState<boolean | null>(null);

  useEffect(() => {
    Linking.getInitialURL().then(
      url => setClipped(url !== 'rnrepro://unclipped'),
      () => setClipped(true),
    );
  }, []);

  if (clipped == null) {
    return <View style={styles.screen} />;
  }

  const rows = [];
  for (let n = 1; n <= rowCount; n += 1) {
    rows.push(
      n === disabledRow ? (
        <Row key={n} label={`row ${n}, disabled`} disabled />
      ) : (
        <Row key={n} label={`row ${n}`} />
      ),
    );
  }

  return (
    <View style={styles.screen}>
      <Text style={styles.caption}>
        {`removeClippedSubviews=${String(
          clipped,
        )}, enableCustomFocusSearchOnClippedElementsAndroid=${String(
          enableCustomFocusSearchOnClippedElementsAndroid(),
        )}`}
      </Text>
      <Text style={styles.caption}>
        Press Tab with a hardware keyboard: from row 11, Tab should go to row
        13.
      </Text>
      <ScrollView removeClippedSubviews={clipped} style={styles.list}>
        {rows}
      </ScrollView>
      <Row label="after the list" />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: 'white',
    paddingHorizontal: 24,
    paddingTop: 64,
    gap: 16,
  },
  caption: {
    color: 'black',
    fontSize: 16,
  },
  list: {
    flexGrow: 0,
    height: 300,
    borderColor: '#bbbbbb',
    borderWidth: 1,
  },
  rowWrapper: {
    marginBottom: 12,
  },
  row: {
    height: 56,
    justifyContent: 'center',
    backgroundColor: '#eeeeee',
    borderColor: '#eeeeee',
    borderWidth: 4,
    paddingHorizontal: 20,
  },
  disabled: {
    opacity: 0.4,
  },
  focused: {
    borderColor: '#d81b60',
  },
  rowText: {
    color: 'black',
    fontSize: 16,
  },
});

export default App;
