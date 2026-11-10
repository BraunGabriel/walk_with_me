#!/bin/bash
# Grant permissions to the app on the booted iOS simulator.
# Usage: ./scripts/sim_permissions.sh [lat,lng]
set -e

BUNDLE_ID="com.example.walkWithMe"
DEVICE="booted"
LOCATION="${1:-42.9634,-85.6681}"

if ! xcrun simctl list devices booted | grep -q Booted; then
  echo "No simulator is booted. Open one from DeviceHub first."
  exit 1
fi

xcrun simctl privacy "$DEVICE" grant location-always "$BUNDLE_ID"
xcrun simctl privacy "$DEVICE" grant microphone "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl location "$DEVICE" set "$LOCATION"

echo "Granted permissions to $BUNDLE_ID and set location to $LOCATION"
