# Android: keyboard Tab stays put at a disabled `Pressable` that a `removeClippedSubviews` ScrollView has clipped

React Native 0.90.0-nightly-20261119-f4f8b6a1f, new architecture, from the [React Native reproducer template](https://github.com/react-native-community/reproducer-react-native). `enableCustomFocusSearchOnClippedElementsAndroid` is at its default, `true`, which the app shows at the top.

`ReproducerApp/App.tsx` renders a 300-point `ScrollView` holding twenty `Pressable` rows, "row 1" to "row 20", each in a `View` of its own; row 12 is `disabled` and labelled "row 12, disabled". A `Pressable` "after the list" sits below the `ScrollView`. Opened with no URL, or with `rnrepro://clipped`, the `ScrollView` sets `removeClippedSubviews`; opened with `rnrepro://unclipped` it does not.

With a hardware keyboard, Tab should go from row 11 to row 13, passing over the disabled row, whether or not `removeClippedSubviews` is set.

## Steps

By hand, on an Android device with a hardware keyboard:

1. Build and install the release APK: `cd ReproducerApp && yarn install && cd android && ./gradlew assembleRelease && adb install -r app/build/outputs/apk/release/app-release.apk`.
2. Open the app and press Tab eleven times. A focused row gets a pink border, and the list scrolls to keep it in view: focus goes row 1, row 2, … row 11.
3. Press Tab again, as often as you like: focus stays on row 11.
4. For comparison, open the list without `removeClippedSubviews`: `adb shell am start -a android.intent.action.VIEW -d rnrepro://unclipped -n com.reproducerapp/.MainActivity`, and press Tab twelve times: focus goes from row 11 to row 13.

Without a keyboard: `adb shell input keyevent KEYCODE_TAB`.

Scripted: `./reproduce.sh`, with one Android device attached, builds and installs the app, then for the list without `removeClippedSubviews` and the list with it starts the app afresh, presses Tab fifteen times and reads which view holds focus after each press from `uiautomator dump`. It exits 1 while Tab stays on row 11 in the list with `removeClippedSubviews` and goes from row 11 to row 13 in the one without, 0 once it goes from row 11 to row 13 in both, and 2 when the list without `removeClippedSubviews` does not go from row 11 to row 13, a walk never reaches row 11, the disabled row or another view takes focus, or a step fails.
