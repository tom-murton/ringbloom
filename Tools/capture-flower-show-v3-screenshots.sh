#!/bin/bash

set -euo pipefail

workspace_root="$(cd "$(dirname "$0")/.." && pwd)"
bundle_id="com.tommurton.ringbloom"
simulator_udid=""
app_path=""
raw_dir=""
expected_version=""
expected_build=""

usage() {
    echo "Usage: $0 --simulator <udid> --app <Ringbloom.app> --version <version> --build <build> [--output <directory>]" >&2
}

require_value() {
    if [[ $# -lt 2 || -z "$2" ]]; then
        echo "Missing value for $1" >&2
        usage
        exit 64
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    --simulator)
        require_value "$@"
        simulator_udid="$2"
        shift 2
        ;;
    --app)
        require_value "$@"
        app_path="$2"
        shift 2
        ;;
    --version)
        require_value "$@"
        expected_version="$2"
        shift 2
        ;;
    --build)
        require_value "$@"
        expected_build="$2"
        shift 2
        ;;
    --output)
        require_value "$@"
        raw_dir="$2"
        shift 2
        ;;
    *)
        echo "Unknown argument: $1" >&2
        usage
        exit 64
        ;;
    esac
done

if [[ -z "$simulator_udid" || -z "$app_path" || -z "$expected_version" || -z "$expected_build" ]]; then
    echo "Simulator, app bundle, version and build must all be explicit." >&2
    usage
    exit 64
fi

raw_dir="${raw_dir:-$workspace_root/screenshots/flower-show-v3/freemium-${expected_version}-build${expected_build}/raw}"

if [[ ! -d "$app_path" ]]; then
    echo "App bundle not found: $app_path" >&2
    exit 2
fi

info_plist="$app_path/Info.plist"
if [[ ! -f "$info_plist" ]]; then
    echo "App Info.plist not found: $info_plist" >&2
    exit 2
fi

actual_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print:CFBundleIdentifier' "$info_plist")"
actual_version="$(/usr/libexec/PlistBuddy -c 'Print:CFBundleShortVersionString' "$info_plist")"
actual_build="$(/usr/libexec/PlistBuddy -c 'Print:CFBundleVersion' "$info_plist")"

if [[ "$actual_bundle_id" != "$bundle_id" ]]; then
    echo "Candidate bundle mismatch: expected $bundle_id, found $actual_bundle_id at $app_path" >&2
    exit 3
fi
if [[ "$actual_version" != "$expected_version" || "$actual_build" != "$expected_build" ]]; then
    echo "Candidate version mismatch: requested $expected_version ($expected_build), found $actual_version ($actual_build) at $app_path" >&2
    exit 3
fi

packaged_storekit="$(find "$app_path" -type f -name '*.storekit' -print -quit)"
if [[ -n "$packaged_storekit" ]]; then
    echo "Candidate unexpectedly packages a StoreKit test configuration: $packaged_storekit" >&2
    exit 3
fi

echo "Using explicit screenshot candidate: $app_path"
echo "Validated bundle=$actual_bundle_id version=$actual_version build=$actual_build output=$raw_dir"

mkdir -p "$raw_dir"
xcrun simctl boot "$simulator_udid" 2>/dev/null || true
xcrun simctl bootstatus "$simulator_udid" -b
xcrun simctl install "$simulator_udid" "$app_path"
xcrun simctl status_bar "$simulator_udid" override \
    --time 9:41 \
    --dataNetwork wifi \
    --wifiMode active \
    --wifiBars 3 \
    --cellularMode active \
    --cellularBars 4 \
    --batteryState charged \
    --batteryLevel 100

capture() {
    local filename="$1"
    shift

    xcrun simctl launch --terminate-running-process "$simulator_udid" "$bundle_id" \
        -ringbloom.tutorialSeen YES \
        "$@" >/dev/null
    sleep 2
    axe screenshot --udid "$simulator_udid" --output "$raw_dir/$filename.png" >/dev/null
    echo "Captured $filename.png"
}

capture "01-two-modes" \
    --screenshot-flower-show-menu \
    --flower-show-access=sample \
    --flower-show-class=1

capture "02-class-book" \
    --screenshot-flower-show-class-book \
    --flower-show-access=sample \
    --flower-show-class=5

capture "03-purchase" \
    --screenshot-flower-show-purchase \
    --flower-show-access=sample \
    --flower-show-display-price=£2.99 \
    --flower-show-class=6

capture "04-gameplay" \
    --screenshot-flower-show-game \
    --flower-show-access=full-purchase \
    --flower-show-class=11

capture "05-special-rules" \
    --screenshot-flower-show-rules \
    --flower-show-access=full-purchase \
    --flower-show-class=24

capture "06-champion-circuit" \
    --screenshot-champion-home \
    --flower-show-access=full-purchase

capture "07-grand-champion" \
    --screenshot-flower-show-win \
    --flower-show-access=full-purchase \
    --flower-show-class=30

capture "review-purchase" \
    --screenshot-flower-show-purchase \
    --flower-show-access=sample \
    --flower-show-display-price=£2.99 \
    --flower-show-class=6

echo "FLOWER_SHOW_V3_SCREENSHOTS_CAPTURED directory=$raw_dir count=7 plus review-purchase"
