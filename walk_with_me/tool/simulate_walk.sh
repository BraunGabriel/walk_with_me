#!/usr/bin/env bash
# Simulates walking a tour in the iOS Simulator, so you can test navigation,
# rerouting and "along the way" highlights without being on campus.
#
# Usage:  tool/simulate_walk.sh [tour-id] [speed m/s]
#   tour-id  from assets/data/tours.json (default: highlights)
#   speed    default 4 (brisk; real walking is ~1.4)
#
# Start the app, then the tour in the app, then run this. Stop with:
#   xcrun simctl location booted clear
#
# Note: it walks straight lines between stops, so you'll sometimes see the
# app reroute when the straight line cuts across buildings — that's expected.

set -euo pipefail
cd "$(dirname "$0")/.."

TOUR="${1:-highlights}"
SPEED="${2:-4}"

WAYPOINTS=$(python3 -I - "$TOUR" <<'PY'
import json, sys
tour_id = sys.argv[1]
pois = {p["id"]: p for p in json.load(open("assets/data/pois.json"))["pois"]}
tours = {t["id"]: t for t in json.load(open("assets/data/tours.json"))["tours"]}
if tour_id not in tours:
    sys.exit(f"Unknown tour '{tour_id}'. Options: {', '.join(tours)}")
stops = [pois[s] for s in tours[tour_id]["stops"]]
first = stops[0]
# Start ~120 m south-west of the first stop so there's a route to follow.
print(f'{first["latitude"] - 0.0008},{first["longitude"] - 0.0008}')
for s in stops:
    print(f'{s["latitude"]},{s["longitude"]}')
PY
)

echo "Walking tour '$TOUR' at ${SPEED} m/s through $(echo "$WAYPOINTS" | wc -l | tr -d ' ') waypoints..."
# Begin at the start point so the app can fetch the first route.
xcrun simctl location booted set "$(echo "$WAYPOINTS" | head -1)"
sleep 3
echo "$WAYPOINTS" | xcrun simctl location booted start --speed="$SPEED" --distance=3 -
echo "Running. Stop with: xcrun simctl location booted clear"
