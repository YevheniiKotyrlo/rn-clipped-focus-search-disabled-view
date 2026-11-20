#!/usr/bin/env bash
# Exit 1 while hardware-keyboard Tab stays on "row 11" inside a ScrollView with removeClippedSubviews, where the next
# row, row 12, is a disabled Pressable, though the same list without removeClippedSubviews goes from row 11 to row 13;
# 0 once Tab goes from row 11 to row 13 in both; 2 when the list without removeClippedSubviews does not go from row 11
# to row 13, a walk never reaches row 11, the disabled row or another view takes focus, or a step fails.
# Needs adb with one Android device attached (ANDROID_SERIAL picks one of several), node, yarn and a JDK.
set -u

package=com.reproducerapp
# Enough presses to reach row 11 from a fresh launch and press Tab four more times there.
presses=15

fail_step() {
    echo "step failed: $1"
    exit 2
}

# The path as the platform's own programs take it: Git Bash's /c/... becomes C:/... for adb on Windows.
native_path() {
    if command -v cygpath > /dev/null; then
        cygpath -m "$1"
    else
        printf '%s\n' "$1"
    fi
}

# Sets the named variable to a device property, without the carriage return adb's shell ends it with.
read_device_property() {
    local value
    value="$(adb shell getprop "$2")" || fail_step "adb shell getprop $2: ${value}"
    printf -v "$1" '%s' "${value//$'\r'/}"
}

dump_window() {
    adb shell uiautomator dump /sdcard/clipped-focus-reproducer.xml > /dev/null 2>&1
    adb exec-out cat /sdcard/clipped-focus-reproducer.xml 2> /dev/null
    adb shell rm -f /sdcard/clipped-focus-reproducer.xml
}

# wait_for_text <text>: waits for a node whose text attribute is the text given.
wait_for_text() {
    local text=$1 attempt hierarchy
    for ((attempt = 1; attempt <= 30; attempt += 1)); do
        hierarchy="$(dump_window)"
        if [[ "${hierarchy}" == *"text=\"${text}\""* ]]; then
            return 0
        fi
        sleep 1
    done
    return 1
}

# launch_app <clipped|unclipped>: starts the app afresh with rnrepro://<mode>, so no view holds focus when the walk
# begins, and waits for the caption that names the ScrollView's removeClippedSubviews and the feature flag.
launch_app() {
    local mode=$1 expected=false caption
    [[ "${mode}" == clipped ]] && expected=true
    caption="removeClippedSubviews=${expected}, enableCustomFocusSearchOnClippedElementsAndroid=true"
    adb shell am force-stop "${package}" > /dev/null || fail_step "adb shell am force-stop ${package}"
    adb shell am start -W -a android.intent.action.VIEW -d "rnrepro://${mode}" -n "${package}/.MainActivity" \
        > /dev/null || fail_step "starting ${package} with rnrepro://${mode}"
    wait_for_text "${caption}" || fail_step "the app showed no \"${caption}\""
    echo "app shows: ${caption}"
}

# Prints the content-desc of the node uiautomator reads as focused, or "(nothing focused)".
focused_label() {
    local hierarchy node pattern='content-desc="([^"]*)"'
    hierarchy="$(dump_window)"
    while IFS= read -r node; do
        if [[ "${node}" == *'focused="true"'* && "${node}" =~ ${pattern} ]]; then
            printf '%s\n' "${BASH_REMATCH[1]}"
            return 0
        fi
    done <<< "${hierarchy//<node/$'\n'<node}"
    printf '%s\n' "(nothing focused)"
}

# walk <clipped|unclipped>: starts the app afresh, presses Tab `presses` times and prints the view that holds focus
# after each press. Sets `walk_verdict` to passes (the press after the first stop on row 11 lands on row 13), stays
# (every press after the first stop on row 11 leaves it there), or other, and `walk_text` to what the walk did.
walk() {
    local mode=$1 count label stops=() first=-1 after held=0 clipping=off
    [[ "${mode}" == clipped ]] && clipping=on
    launch_app "${mode}"
    echo "== Tab, ${presses} presses from a fresh launch, removeClippedSubviews ${clipping}"
    for ((count = 1; count <= presses; count += 1)); do
        adb shell input keyevent KEYCODE_TAB > /dev/null || fail_step "pressing Tab"
        sleep 1
        label="$(focused_label)"
        echo "  Tab ${count}: \"${label}\" holds focus"
        stops+=("${label}")
        if [[ "${label}" == "row 11" && "${first}" -lt 0 ]]; then
            first=$((count - 1))
        fi
    done
    for label in "${stops[@]}"; do
        if [[ "${label}" == "row 12, disabled" ]]; then
            walk_verdict=other
            walk_text="Tab lands on the disabled \"row 12, disabled\""
            return 0
        fi
    done
    if ((first < 0)); then
        walk_verdict=other
        walk_text="Tab never reaches \"row 11\""
        return 0
    fi
    if ((first + 1 >= presses)); then
        walk_verdict=other
        walk_text="Tab reaches \"row 11\" only on its last press"
        return 0
    fi
    after="${stops[first + 1]}"
    if [[ "${after}" == "row 13" ]]; then
        walk_verdict=passes
        walk_text="Tab goes from \"row 11\" to \"row 13\""
        return 0
    fi
    for ((count = first + 1; count < presses; count += 1)); do
        [[ "${stops[count]}" == "row 11" ]] && held=$((held + 1))
    done
    if ((held == presses - first - 1)); then
        walk_verdict=stays
        walk_text="Tab stays on \"row 11\" for the ${held} presses after it and never reaches \"row 13\""
        return 0
    fi
    walk_verdict=other
    if [[ "${after}" == "row 11" ]]; then
        for ((count = first + 1; count < presses; count += 1)); do
            [[ "${stops[count]}" == "row 11" ]] || break
        done
        walk_text="Tab stays on \"row 11\" for $((count - first - 1)) presses, then goes to \"${stops[count]}\""
    else
        walk_text="Tab goes from \"row 11\" to \"${after}\""
    fi
}

# Walks the list without removeClippedSubviews, which shows where Tab goes from row 11, then the list with it, and
# exits with the verdict.
check_navigation() {
    local control control_text
    walk unclipped
    control="${walk_verdict}"
    control_text="without removeClippedSubviews, ${walk_text}"
    walk clipped
    local summary="with removeClippedSubviews, ${walk_text}; ${control_text}"

    if [[ "${control}" != passes || "${walk_verdict}" == other ]]; then
        echo "SUMMARY: inconclusive: ${summary}"
        exit 2
    fi
    if [[ "${walk_verdict}" == stays ]]; then
        echo "SUMMARY: keyboard focus stays on the row before a clipped disabled Pressable: ${summary}"
        exit 1
    fi
    echo "SUMMARY: keyboard focus passes over a clipped disabled Pressable: ${summary}"
    exit 0
}

main() {
    local here app
    here="$(cd "$(dirname "$0")" && pwd)"
    app="${here}/ReproducerApp"

    local system node_version java_version
    system="$(uname -sm)"
    node_version="$(node --version 2>&1)" || fail_step "node --version: ${node_version}"
    java_version="$(java -version 2>&1)" || fail_step "java -version: ${java_version}"
    echo "${system}, node ${node_version}, ${java_version%%$'\n'*}"

    local device_state
    device_state="$(adb get-state 2>&1)"
    [[ "${device_state}" == "device" ]] || fail_step "adb get-state: ${device_state}"
    local model release sdk abi
    read_device_property model ro.product.model
    read_device_property release ro.build.version.release
    read_device_property sdk ro.build.version.sdk
    read_device_property abi ro.product.cpu.abi
    echo "device: ${model}, Android ${release} (API ${sdk}), ${abi}"

    local install_output react_native_version
    install_output="$(cd "${app}" && yarn install --frozen-lockfile --non-interactive 2>&1)" ||
        { printf '%s\n' "${install_output}" | tail -n 20; fail_step "yarn install"; }
    react_native_version="$(cd "${app}" && node -p 'require("react-native/package.json").version' 2>&1)" ||
        fail_step "reading react-native's version: ${react_native_version}"
    echo "react-native ${react_native_version}, new architecture"

    echo "== ./gradlew :app:assembleRelease -PreactNativeArchitectures=${abi}"
    local build_output
    build_output="$(cd "${app}/android" && ./gradlew --no-daemon --console=plain :app:assembleRelease \
        "-PreactNativeArchitectures=${abi}" 2>&1)" ||
        { printf '%s\n' "${build_output}" | tail -n 40; fail_step "the release build"; }

    local apk install_result
    apk="$(native_path "${app}/android/app/build/outputs/apk/release/app-release.apk")"
    install_result="$(adb install -r "${apk}" 2>&1)" || fail_step "adb install: ${install_result}"

    check_navigation
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
