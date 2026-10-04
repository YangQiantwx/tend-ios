#!/bin/bash
# Build and open the isolated sample-data mode on an installed iPhone Simulator.
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: scripts/run_demo.sh [--reset] [SIMULATOR_UDID]

Build and run Tend with sample history. By default, reuse a booted iPhone
Simulator or choose the first available iPhone. No runtime is downloaded.
--reset recreates only the sample records, relative to today's date.
Omit --reset to keep changes from earlier demonstrations.
USAGE
}

reset_demo=false
device_id=""
for argument in "$@"; do
    case "$argument" in
        --reset) reset_demo=true ;;
        --help|-h) usage; exit 0 ;;
        --*) printf 'Unknown option: %s\n' "$argument" >&2; usage >&2; exit 2 ;;
        *)
            if [[ -n "$device_id" ]]; then
                printf 'Supply only one Simulator UDID.\n' >&2
                exit 2
            fi
            device_id="$argument"
            ;;
    esac
done

project_root="$(cd "$(dirname "$0")/.." && pwd)"
if [[ ! -f "$project_root/Tend.xcodeproj/project.pbxproj" ]]; then
    printf 'Tend.xcodeproj is missing from %s.\n' "$project_root" >&2
    exit 1
fi
if ! /usr/bin/xcodebuild -version || ! /usr/bin/xcrun --sdk iphonesimulator --show-sdk-path; then
    printf 'Select a full Xcode installation in Xcode Settings → Locations → Command Line Tools.\n' >&2
    exit 1
fi

available_devices="$(/usr/bin/xcrun simctl list devices available)"
iphone_devices="$(printf '%s\n' "$available_devices" | /usr/bin/awk '
    /iPhone/ && /\([[:xdigit:]-]+\)/ {
        match($0, /\([[:xdigit:]-]+\)/)
        id = substr($0, RSTART + 1, RLENGTH - 2)
        if (length(id) == 36) print id, ($0 ~ /\(Booted\)/ ? "Booted" : "Shutdown")
    }')"
if [[ -z "$iphone_devices" ]]; then
    printf 'No available iPhone Simulator. Add an iOS runtime and iPhone device in Xcode, then retry.\n' >&2
    exit 1
fi
if [[ -z "$device_id" ]]; then
    device_id="$(printf '%s\n' "$iphone_devices" | /usr/bin/awk '$2 == "Booted" { print $1; exit }')"
    if [[ -z "$device_id" ]]; then
        device_id="$(printf '%s\n' "$iphone_devices" | /usr/bin/awk 'NR == 1 { print $1 }')"
    fi
fi
device_state="$(printf '%s\n' "$iphone_devices" | /usr/bin/awk -v id="$device_id" '$1 == id { print $2 }')"
if [[ -z "$device_state" ]]; then
    printf 'Simulator %s is not an available iPhone. Run xcrun simctl list devices available to choose one.\n' "$device_id" >&2
    exit 1
fi

build_dir="${TEND_DEMO_BUILD_DIR:-${TMPDIR:-/tmp}/tend-demo-build-${UID}}"
printf 'Building Tend for %s. Build cache: %s\n' "$device_id" "$build_dir"
if ! /usr/bin/xcodebuild -project "$project_root/Tend.xcodeproj" -scheme Tend \
    -configuration Debug -destination "platform=iOS Simulator,id=$device_id" \
    -derivedDataPath "$build_dir" CODE_SIGNING_ALLOWED=NO build; then
    printf 'Build failed. Review the Xcode error above; no app data was reset.\n' >&2
    exit 1
fi

if [[ "$device_state" != "Booted" ]]; then
    /usr/bin/xcrun simctl boot "$device_id"
fi
/usr/bin/xcrun simctl bootstatus "$device_id" -b
developer_dir="$(/usr/bin/xcode-select -p)"
simulator_app=""
for candidate in "$developer_dir/../Applications/DeviceHub.app" \
    "$developer_dir/Applications/Simulator.app" \
    "$developer_dir/../Applications/Simulator.app"; do
    if [[ -d "$candidate" ]]; then simulator_app="$candidate"; break; fi
done
if [[ -z "$simulator_app" ]]; then
    printf 'The selected Xcode has no Simulator or Device Hub app. Check the Xcode installation.\n' >&2
    exit 1
fi
/usr/bin/open "$simulator_app" --args -CurrentDeviceUDID "$device_id"
/usr/bin/xcrun simctl install "$device_id" "$build_dir/Build/Products/Debug-iphonesimulator/Tend.app"
# A currently running app must restart to switch its data directory.
/usr/bin/xcrun simctl terminate "$device_id" org.tend.app >/dev/null 2>&1 || true
launch_arguments=(--demo)
if [[ "$reset_demo" == true ]]; then launch_arguments+=(--reset-demo-data); fi
/usr/bin/xcrun simctl launch "$device_id" org.tend.app "${launch_arguments[@]}"
printf 'Tend is open in sample-data mode. Ordinary records are preserved.\n'
