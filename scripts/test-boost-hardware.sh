#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
swift_flags=(-g)
case "${1:-}" in
    "") ;;
    --thread-sanitizer) swift_flags+=(-sanitize=thread) ;;
    *) echo "Usage: bash scripts/test-boost-hardware.sh [--thread-sanitizer]"; exit 2 ;;
esac
if pgrep -x MacEdgeLight >/dev/null; then
    echo "Quit MacEdgeLight first so two processes cannot write the gamma table."
    exit 1
fi
boost_check_dir="$(mktemp -d -t macedgelight-boost-check)"
trap 'rm -rf "$boost_check_dir"' EXIT
xcrun swiftc "${swift_flags[@]}" "$repo_dir/MacEdgeLight/DisplayBrightnessManager.swift" \
    "$repo_dir/scripts/BoostHardwareCheck.swift" \
    -framework Cocoa -framework Metal -framework QuartzCore \
    -o "$boost_check_dir/BoostHardwareCheck"
"$boost_check_dir/BoostHardwareCheck"
